// Secuenciador único del bus Wishbone: arbitra TX, servicio, reconfiguración y RAL.
// Ref: V-WB-01. Dueño: Eric.
class wishB_sequencer extends uvm_sequencer #(wishB_item);
  `uvm_component_utils(wishB_sequencer)

  config_wishB cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(config_wishB)::get(this, "", "config_wishB", cfg))
      `uvm_fatal("CFG", "No se encontró config_wishB")
    // Los ítems de varias secuencias se intercalan; las de varios pasos (DLAB) usan lock().
    set_arbitration(UVM_SEQ_ARB_RANDOM);
  endfunction

endclass : wishB_sequencer