// Cobertura de la interfaz serie. Se muestrea desde los monitores, no desde el driver ni desde el scoreboard.
// Se muestrea la configuración de cada trama, el divisor de baudios, el nivel de la FIFO TX y los errores de recepción.

`uvm_analysis_imp_decl(_cov_wb)
`uvm_analysis_imp_decl(_cov_tx)
`uvm_analysis_imp_decl(_cov_rx)

class uart_serie_cov extends uvm_component;
  `uvm_component_utils(uart_serie_cov)

  // Mismas tres entradas que el scoreboard serie
  uvm_analysis_imp_cov_wb #(wishB_item, uart_serie_cov) wb_imp;
  uvm_analysis_imp_cov_tx #(serie_item, uart_serie_cov) stx_imp;
  uvm_analysis_imp_cov_rx #(serie_item, uart_serie_cov) srx_imp;

  // Los asigna el ambiente, igual que en el scoreboard
  uart_ral_adapter       adapter;
  dlab0_rm_pkg::dlab0_rm regs;

  // Copia de DLL y DLM según lo que se escribe por el bus, para muestrear cg_div
  bit [7:0] dll, dlm;

  // Caracteres escritos en THR que todavía no han salido completos por stx.
  // Es una aproximación del nivel de la FIFO TX: cuenta también el que va saliendo por el registro de desplazamiento.
  int unsigned tx_pending;

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

  // Nivel de la FIFO TX, muestreado al escribir THR.
  covergroup cg_traffic with function sample(int unsigned level);
    cp_fifo_level : coverpoint level {
      bins empty    = {0};
      bins partial  = {[1:15]};
      bins full     = {16};
      bins overflow = {[17:$]};
    }
    // Escribir con la FIFO llena
    cp_tx_write_full : coverpoint (level >= 16) {
      bins no  = {0};
      bins yes = {1};
    }
  endgroup

  // Errores que traía la trama al entrar por srx. Cuando el modelo revise LSR, esto se va a muestrear ahí y se le agregan cp_oe y cp_tl.
  covergroup cg_err with function sample(bit pe, bit fe, bit bi);
    cp_pe : coverpoint pe;
    cp_fe : coverpoint fe;
    cp_bi : coverpoint bi;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    wb_imp      = new("wb_imp",  this);
    stx_imp     = new("stx_imp", this);
    srx_imp     = new("srx_imp", this);
    cg_line_cfg = new();
    cg_tx_break = new();
    cg_div      = new();
    cg_traffic  = new();
    cg_err      = new();
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    if (adapter == null || regs == null)
      `uvm_fatal("COV", "uart_serie_cov sin adaptador o sin modelo de registros")
  endfunction

  // Solo interesan las escrituras a LCR, DLL, DLM y THR
  function void write_cov_wb(wishB_item it);
    uvm_reg_bus_op rw;
    bit            dlab;
    adapter.bus2reg(it, rw);
    if (rw.kind != UVM_WRITE)
      return;
    dlab = regs.LCR.dlab.get_mirrored_value();
    case (rw.addr)
      0: begin
        if (dlab) begin
          dll = rw.data[7:0];
          cg_div.sample({dlm, dll});
        end else begin
          cg_traffic.sample(tx_pending);
          tx_pending++;
        end
      end
      1: if (dlab) begin
        dlm = rw.data[7:0];
        cg_div.sample({dlm, dll});
      end
      3: cg_tx_break.sample(rw.data[6]);
      default: ;
    endcase
  endfunction

  function void write_cov_tx(serie_item it);
    cg_line_cfg.sample(it.lcr, it.dir);
    if (tx_pending > 0)
      tx_pending--;
  endfunction

  function void write_cov_rx(serie_item it);
    cg_line_cfg.sample(it.lcr, it.dir);
    cg_err.sample(it.pe, it.fe, it.bi);
  endfunction

// El reporte de cobertura se hace al final de la simulación, no en cada fase. Se muestrean todos los covergroups, no solo los que se muestrean desde el scoreboard.
  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("Cobertura serie: line_cfg %0.1f%%, tx_break %0.1f%%, div %0.1f%%, traffic %0.1f%%, err %0.1f%%",
              cg_line_cfg.get_inst_coverage(), cg_tx_break.get_inst_coverage(), cg_div.get_inst_coverage(),
              cg_traffic.get_inst_coverage(), cg_err.get_inst_coverage()), UVM_LOW)
  endfunction

endclass : uart_serie_cov
