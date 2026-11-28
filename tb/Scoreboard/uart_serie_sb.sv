// Scoreboard serie del ambiente: recibe lo que ven los monitores y se lo pasa al modelo de referencia.
// Sale del scoreboard de la prueba de humo; la lógica de comparar sigue estando en uart_serie_model.

`uvm_analysis_imp_decl(_ser_wb)
`uvm_analysis_imp_decl(_ser_tx)
`uvm_analysis_imp_decl(_ser_rx)
`uvm_analysis_imp_decl(_ser_pop)
`uvm_analysis_imp_decl(_ser_push)

class uart_serie_sb extends uvm_component;
  `uvm_component_utils(uart_serie_sb)

  // Una entrada por cada monitor: Wishbone, stx y srx, más los avisos de las FIFOs del DUT
  uvm_analysis_imp_ser_wb    #(wishB_item, uart_serie_sb) wb_imp;
  uvm_analysis_imp_ser_tx    #(serie_item, uart_serie_sb) stx_imp;
  uvm_analysis_imp_ser_rx    #(serie_item, uart_serie_sb) srx_imp;
  uvm_analysis_imp_ser_pop   #(serie_item, uart_serie_sb) pop_imp;
  uvm_analysis_imp_ser_push  #(serie_item, uart_serie_sb) push_imp;

  uart_serie_model model;

  // Los asigna el ambiente con lo que ya tiene el RAL de Eric:
  // el adaptador traduce las transacciones del bus y el modelo de registros dice si DLAB está en 1
  uart_ral_adapter       adapter;
  dlab0_rm_pkg::dlab0_rm regs;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    wb_imp  = new("wb_imp",  this);
    stx_imp = new("stx_imp", this);
    srx_imp = new("srx_imp", this);
    pop_imp = new("pop_imp", this);
    push_imp = new("push_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    model = uart_serie_model::type_id::create("model");
  endfunction

  // Si el ambiente se olvidó de pasarnos el RAL, mejor avisar antes de que arranque el tráfico
  function void start_of_simulation_phase(uvm_phase phase);
    if (adapter == null || regs == null)
      `uvm_fatal("SB", "uart_serie_sb sin adaptador o sin modelo de registros")
  endfunction

  // Del bus interesan THR y RBR (dirección 0 con DLAB en 0), FCR (2), LCR (3) y MCR (4).
  // Con DLAB en 1 la dirección 0 es DLL, y eso no es tráfico serie.
  function void write_ser_wb(wishB_item it);
    uvm_reg_bus_op rw;
    bit [7:0]      lcr;
    adapter.bus2reg(it, rw);
    lcr = 8'(regs.LCR.get_mirrored_value());

    if (rw.kind == UVM_READ) begin
      if (rw.addr == 0 && !lcr[7])
        model.read_rbr(rw.data[7:0]);
      return;
    end

    case (rw.addr)
      0: if (!lcr[7]) model.write_thr(rw.data[7:0]);
      2: model.write_fcr(rw.data[7:0]);
      3: model.write_lcr(rw.data[7:0]);
      4: model.write_mcr(rw.data[7:0]);
      default: ;
    endcase
  endfunction

  // Con break activo lo que sale no se ve en stx, así que no se compara
  function void write_ser_pop(serie_item it);
    if (!it.lcr[6]) model.tx_pop(it.lcr);
  endfunction

  // Entró un byte a la FIFO RX del DUT; el modelo solo lo usa en loopback
  function void write_ser_push(serie_item it);
    model.rx_push();
  endfunction

  function void write_ser_tx(serie_item it);
    if (!it.lcr[6]) model.check_stx(it);
  endfunction

  function void write_ser_rx(serie_item it);
    model.got_srx(it);
  endfunction

  function void report_phase(uvm_phase phase);
    model.report();
  endfunction

endclass : uart_serie_sb
