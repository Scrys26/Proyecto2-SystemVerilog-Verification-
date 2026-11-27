// Scoreboard serie del ambiente: recibe lo que ven los monitores y se lo pasa al modelo de referencia.
// Sale del scoreboard de la prueba de humo; la lógica de comparar sigue estando en uart_serie_model.

`uvm_analysis_imp_decl(_ser_wb)
`uvm_analysis_imp_decl(_ser_tx)
`uvm_analysis_imp_decl(_ser_rx)
`uvm_analysis_imp_decl(_ser_start)

class uart_serie_sb extends uvm_component;
  `uvm_component_utils(uart_serie_sb)

  // Una entrada por cada monitor: Wishbone, stx y srx, más el aviso de bit de inicio en stx
  uvm_analysis_imp_ser_wb    #(wishB_item, uart_serie_sb) wb_imp;
  uvm_analysis_imp_ser_tx    #(serie_item, uart_serie_sb) stx_imp;
  uvm_analysis_imp_ser_rx    #(serie_item, uart_serie_sb) srx_imp;
  uvm_analysis_imp_ser_start #(serie_item, uart_serie_sb) start_imp;

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
    start_imp = new("start_imp", this);
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

  // Solo interesan los accesos a la dirección 0 con DLAB en 0: escribir ahí es THR y leer es RBR.
  // Con DLAB en 1 esa misma dirección es DLL, y eso no es tráfico serie.
  function void write_ser_wb(wishB_item it);
    uvm_reg_bus_op rw;
    adapter.bus2reg(it, rw);
    if (rw.addr != 0 || regs.LCR.dlab.get_mirrored_value() == 1)
      return;
    if (rw.kind == UVM_WRITE)
      model.write_thr(rw.data[7:0]);
    else
      model.read_rbr(rw.data[7:0]);
  endfunction

  // El DUT acaba de sacar un byte de la FIFO TX
  function void write_ser_start(serie_item it);
    model.tx_started();
  endfunction

  function void write_ser_tx(serie_item it);
    model.check_stx(it);
  endfunction

  function void write_ser_rx(serie_item it);
    model.got_srx(it);
  endfunction

  function void report_phase(uvm_phase phase);
    model.report();
  endfunction

endclass : uart_serie_sb
