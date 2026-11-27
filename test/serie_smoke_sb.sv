// Scoreboard de la prueba de humo serie: conecta los monitores con el modelo de referencia.
// Es provisional, mientras no exista uart_scoreboard; solo sirve para probar el agente serie.

`uvm_analysis_imp_decl(_wb)
`uvm_analysis_imp_decl(_stx)
`uvm_analysis_imp_decl(_srx)

class serie_smoke_sb extends uvm_component;
  `uvm_component_utils(serie_smoke_sb)

  // Una entrada por cada monitor: Wishbone, stx y srx
  uvm_analysis_imp_wb  #(wishB_item, serie_smoke_sb) wb_imp;
  uvm_analysis_imp_stx #(serie_item, serie_smoke_sb) stx_imp;
  uvm_analysis_imp_srx #(serie_item, serie_smoke_sb) srx_imp;

  uart_serie_model model;

  // Los asigna la prueba: el adaptador traduce las transacciones del bus y el RAL dice si DLAB está en 1
  uart_ral_adapter       adapter;
  dlab0_rm_pkg::dlab0_rm regs;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    wb_imp  = new("wb_imp",  this);
    stx_imp = new("stx_imp", this);
    srx_imp = new("srx_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    model = uart_serie_model::type_id::create("model");
  endfunction

  // Solo interesan los accesos a la dirección 0 con DLAB en 0: escribir ahí es THR y leer es RBR.
  // Con DLAB en 1 esa misma dirección es DLL, y eso no es tráfico serie.
  function void write_wb(wishB_item it);
    uvm_reg_bus_op rw;
    adapter.bus2reg(it, rw);
    if (rw.addr != 0 || regs.LCR.dlab.get_mirrored_value() == 1)
      return;
    if (rw.kind == UVM_WRITE)
      model.write_thr(rw.data[7:0]);
    else
      model.read_rbr(rw.data[7:0]);
  endfunction

  function void write_stx(serie_item it);
    model.check_stx(it);
  endfunction

  function void write_srx(serie_item it);
    model.got_srx(it);
  endfunction

  function void report_phase(uvm_phase phase);
    model.report();
  endfunction

endclass : serie_smoke_sb
