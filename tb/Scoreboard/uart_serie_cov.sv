// Cobertura de la interfaz serie. Se muestrea desde los monitores, no desde el driver ni desde el scoreboard.
// Se muestrea la configuración de cada trama, el divisor de baudios, el tráfico, las FIFOs y los errores de recepción.

`uvm_analysis_imp_decl(_cov_wb)
`uvm_analysis_imp_decl(_cov_tx)
`uvm_analysis_imp_decl(_cov_rx)
`uvm_analysis_imp_decl(_cov_pop)
`uvm_analysis_imp_decl(_cov_push)

class uart_serie_cov extends uvm_component;
  `uvm_component_utils(uart_serie_cov)

  // Desde dónde se muestrea cg_traffic: cada coverpoint usa solo una de estas fuentes
  typedef enum {SRC_THR, SRC_SRX, SRC_LSR, SRC_TXB, SRC_RXB, SRC_BUS} src_e;

  // Las mismas entradas que el scoreboard serie, más los avisos de las FIFOs del DUT
  uvm_analysis_imp_cov_wb   #(wishB_item, uart_serie_cov) wb_imp;
  uvm_analysis_imp_cov_tx   #(serie_item, uart_serie_cov) stx_imp;
  uvm_analysis_imp_cov_rx   #(serie_item, uart_serie_cov) srx_imp;
  uvm_analysis_imp_cov_pop  #(serie_item, uart_serie_cov) pop_imp;
  uvm_analysis_imp_cov_push #(serie_item, uart_serie_cov) push_imp;

  // Los asigna el ambiente, igual que en el scoreboard
  uart_ral_adapter       adapter;
  dlab0_rm_pkg::dlab0_rm regs;

  // Copia de DLL y DLM según lo que se escribe por el bus, para muestrear cg_div
  bit [7:0] dll, dlm;

  // Nivel de disparo de la FIFO RX (FCR[7:6]). Después del reset es 14.
  bit [1:0] tl = 2'b11;

  // Nivel de cada FIFO del DUT, contado con las escrituras a THR, las lecturas de RBR y los pulsos de las FIFOs
  int unsigned tx_cnt, rx_cnt;

  // Ráfagas: cuántos caracteres entraron desde que la FIFO estaba vacía, y el nivel más alto que alcanzó la TX
  int unsigned tx_burst, tx_burst_max, rx_burst;

  // Formato de cada trama que pasó por la línea, en las dos direcciones.
  covergroup cg_line_cfg with function sample(bit [7:0] lcr, serie_dir_e dir);
    cp_wls : coverpoint lcr[1:0] {
      bins b5 = {2'b00};
      bins b6 = {2'b01};
      bins b7 = {2'b10};
      bins b8 = {2'b11};
    }
    // Con 5 bits, el bin de 2 bits de parada en realidad es 1.5
    cp_stop : coverpoint lcr[2] {
      bins s1 = {1'b0};
      bins s2 = {1'b1};
    }
    // lcr[5:3] = {stick, par, habilitada}.
    cp_parity : coverpoint lcr[5:3] {
      wildcard bins none = {3'b??0};
      bins odd    = {3'b001};
      bins even   = {3'b011};
      bins stick1 = {3'b101};
      bins stick0 = {3'b111};
    }
    cp_dir : coverpoint dir {
      bins tx = {SER_DIR_TX};
      bins rx = {SER_DIR_RX};
    }
    x_wls_stop_par : cross cp_wls, cp_stop, cp_parity;
    x_wls_dir      : cross cp_wls, cp_dir;
  endgroup

  // Break de transmisión: se toma al escribir LCR, porque mientras dura no sale ninguna trama por stx
  covergroup cg_tx_break with function sample(bit brk);
    cp_tx_break : coverpoint brk {
      bins off = {1'b0};
      bins on  = {1'b1};
    }
  endgroup

  // Divisor escrito por el bus. DL = 0 es legal: el UART no transmite ni recibe.
  covergroup cg_div with function sample(bit [15:0] dl);
    cp_dl : coverpoint dl {
      bins zero = {0};
      bins fast = {[1:16]};
      bins tail = {[17:65535]};
    }
  endgroup

  // Tráfico. Cada coverpoint se llena desde una fuente distinta (src):
  // THR = escritura a THR, SRX = trama en srx, LSR = lectura de LSR, TXB/RXB = fin de una ráfaga, BUS = cualquier acceso
  covergroup cg_traffic with function sample(src_e src, int unsigned n, int unsigned lvl,
                                              bit [7:0] lsr, bit baud_out, bit [3:0] sel, int unsigned addr);
    // Nivel de la FIFO TX justo antes de escribir THR. Con 15 la escritura la llena; con 16 se desborda (AMB-06).
    cp_fifo_level : coverpoint n iff (src == SRC_THR) {
      bins empty    = {0};
      bins partial  = {[1:14]};
      bins full     = {15};
      bins overflow = {16};
    }
    cp_tx_write_full : coverpoint (n == 16) iff (src == SRC_THR) {
      bins no  = {0};
      bins yes = {1};
    }
    // Lo mide el monitor de srx en cada trama (V-RX-02)
    cp_baud_dev : coverpoint baud_out iff (src == SRC_SRX) {
      bins in  = {0};
      bins out = {1};
    }
    // Ráfaga de TX: escrituras a THR desde que la FIFO estaba vacía hasta que se vació otra vez
    cp_burst_len : coverpoint n iff (src == SRC_TXB) {
      bins one       = {1};
      bins short_b   = {[2:15]};
      bins sixteen   = {16};
      bins long_b    = {[17:32]};
      bins very_long = {[33:$]};
    }
    // Nivel más alto que alcanzó la FIFO TX durante esa ráfaga
    cp_burst_level : coverpoint lvl iff (src == SRC_TXB) {
      bins partial = {[1:15]};
      bins full    = {16};
    }
    x_burst_level : cross cp_burst_len, cp_burst_level {
      // Con menos de 16 escrituras la FIFO no se puede llenar
      ignore_bins imposible = binsof(cp_burst_len) intersect {[1:15]} && binsof(cp_burst_level.full);
    }
    // Ráfaga de RX: caracteres que entraron desde que la FIFO estaba vacía hasta que se leyó todo
    cp_rx_len : coverpoint n iff (src == SRC_RXB) {
      bins one     = {1};
      bins short_b = {[2:15]};
      bins sixteen = {16};
      bins overrun = {[17:$]};
    }
    cp_dr   : coverpoint lsr[0] iff (src == SRC_LSR);
    cp_thre : coverpoint lsr[5] iff (src == SRC_LSR);
    cp_temt : coverpoint lsr[6] iff (src == SRC_LSR);
    // Carriles de wb_sel y dirección de cada acceso. No se cruzan: en el bus de 32 bits el carril
    // lo fija la dirección (un solo carril por registro), así que casi todo el cruce sería imposible.
    cp_wb_sel : coverpoint sel iff (src == SRC_BUS) {
      bins lane0 = {4'b0001};
      bins lane1 = {4'b0010};
      bins lane2 = {4'b0100};
      bins lane3 = {4'b1000};
      bins all   = {4'b1111};
    }
    cp_addr : coverpoint addr iff (src == SRC_BUS) {
      bins regs[] = {[0:7]};
      bins debug  = {8, 12};
    }
  endgroup

  // FIFO RX: nivel después de cada carácter que entra, cruzado con el nivel de disparo (V-FIFO-01),
  // y las limpiezas por FCR (V-FIFO-02)
  covergroup cg_fifo with function sample(bit is_push, bit [1:0] tl, int unsigned level, bit clr_rx, bit clr_tx);
    cp_tl : coverpoint tl iff (is_push) {
      bins tl1  = {2'b00};
      bins tl4  = {2'b01};
      bins tl8  = {2'b10};
      bins tl14 = {2'b11};
    }
    cp_rx_level : coverpoint level iff (is_push) {
      bins l1   = {1};
      bins l2_3 = {[2:3]};
      bins l4   = {4};
      bins l5_7 = {[5:7]};
      bins l8   = {8};
      bins l9_13 = {[9:13]};
      bins l14  = {14};
      bins l15_16 = {[15:16]};
    }
    x_tl_level : cross cp_tl, cp_rx_level;
    cp_clear_rx : coverpoint clr_rx iff (!is_push) { bins yes = {1}; }
    cp_clear_tx : coverpoint clr_tx iff (!is_push) { bins yes = {1}; }
  endgroup

  // Errores que el DUT reporta en LSR, tomados de cada lectura de LSR por el bus (V-ERR-01 y V-ERR-02)
  covergroup cg_err with function sample(bit pe, bit fe, bit bi, bit oe, bit [1:0] tl);
    cp_pe : coverpoint pe;
    cp_fe : coverpoint fe;
    cp_bi : coverpoint bi;
    cp_oe : coverpoint oe;
    cp_tl : coverpoint tl {
      bins tl1  = {2'b00};
      bins tl4  = {2'b01};
      bins tl8  = {2'b10};
      bins tl14 = {2'b11};
    }
    x_oe_tl : cross cp_oe, cp_tl;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    wb_imp      = new("wb_imp",   this);
    stx_imp     = new("stx_imp",  this);
    srx_imp     = new("srx_imp",  this);
    pop_imp     = new("pop_imp",  this);
    push_imp    = new("push_imp", this);
    cg_line_cfg = new();
    cg_tx_break = new();
    cg_div      = new();
    cg_traffic  = new();
    cg_fifo     = new();
    cg_err      = new();
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    if (adapter == null || regs == null)
      `uvm_fatal("COV", "uart_serie_cov sin adaptador o sin modelo de registros")
  endfunction

  // Del bus: cada acceso (carril y dirección), lecturas de LSR y RBR, y escrituras a THR, DLL, DLM, FCR y LCR
  function void write_cov_wb(wishB_item it);
    uvm_reg_bus_op rw;
    bit            dlab;
    adapter.bus2reg(it, rw);
    dlab = 1'(regs.LCR.dlab.get_mirrored_value());
    cg_traffic.sample(SRC_BUS, 0, 0, 0, 0, it.sel, 32'(rw.addr));

    if (rw.kind == UVM_READ) begin
      if (rw.addr == 5) begin
        cg_err.sample(rw.data[2], rw.data[3], rw.data[4], rw.data[1], tl);
        cg_traffic.sample(SRC_LSR, 0, 0, rw.data[7:0], 0, 0, 0);
      end
      else if (rw.addr == 0 && !dlab)
        rbr_read();
      return;
    end

    case (rw.addr)
      0: begin
        if (dlab) begin
          dll = rw.data[7:0];
          cg_div.sample({dlm, dll});
        end else
          thr_write();
      end
      1: if (dlab) begin
        dlm = rw.data[7:0];
        cg_div.sample({dlm, dll});
      end
      2: begin
        tl = rw.data[7:6];
        cg_fifo.sample(0, tl, 0, rw.data[1], rw.data[2]);
        if (rw.data[1]) begin rx_cnt = 0; rx_burst = 0; end
        if (rw.data[2]) tx_cnt = 0;
      end
      3: cg_tx_break.sample(rw.data[6]);
      default: ;
    endcase
  endfunction

  // Escritura a THR: se muestrea el nivel de la FIFO TX antes de que entre el byte
  function void thr_write();
    cg_traffic.sample(SRC_THR, tx_cnt, 0, 0, 0, 0, 0);
    tx_burst++;
    if (tx_cnt < 16) tx_cnt++;
    if (tx_cnt > tx_burst_max) tx_burst_max = tx_cnt;
  endfunction

  // Salió un byte de la FIFO TX. Si quedó vacía, terminó la ráfaga.
  function void write_cov_pop(serie_item it);
    if (tx_cnt > 0) tx_cnt--;
    if (tx_cnt == 0 && tx_burst > 0) begin
      cg_traffic.sample(SRC_TXB, tx_burst, tx_burst_max, 0, 0, 0, 0);
      tx_burst     = 0;
      tx_burst_max = 0;
    end
  endfunction

  // Entró un carácter a la FIFO RX (o se perdió por overrun, pero igual cuenta en la ráfaga)
  function void write_cov_push(serie_item it);
    rx_burst++;
    if (rx_cnt < 16) rx_cnt++;
    cg_fifo.sample(1, tl, rx_cnt, 0, 0);
  endfunction

  // Lectura de RBR: si la FIFO RX quedó vacía, terminó la ráfaga
  function void rbr_read();
    if (rx_cnt > 0) rx_cnt--;
    if (rx_cnt == 0 && rx_burst > 0) begin
      cg_traffic.sample(SRC_RXB, rx_burst, 0, 0, 0, 0, 0);
      rx_burst = 0;
    end
  endfunction

  function void write_cov_tx(serie_item it);
    cg_line_cfg.sample(it.lcr, it.dir);
  endfunction

  function void write_cov_rx(serie_item it);
    cg_line_cfg.sample(it.lcr, it.dir);
    cg_traffic.sample(SRC_SRX, 0, 0, 0, it.baud_out, 0, 0);
  endfunction

  // Al final de la corrida se imprime cuánto se llenó cada covergroup
  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("Cobertura serie: line_cfg %0.1f%%, tx_break %0.1f%%, div %0.1f%%, traffic %0.1f%%, fifo %0.1f%%, err %0.1f%%",
              cg_line_cfg.get_inst_coverage(), cg_tx_break.get_inst_coverage(), cg_div.get_inst_coverage(),
              cg_traffic.get_inst_coverage(), cg_fifo.get_inst_coverage(), cg_err.get_inst_coverage()), UVM_LOW)
  endfunction

endclass : uart_serie_cov
