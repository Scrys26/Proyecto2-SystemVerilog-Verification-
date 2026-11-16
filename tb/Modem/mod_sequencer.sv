class mod_sequencer extends uvm_sequencer #(mod_pin_event);
  `uvm_component_utils(mod_sequencer)
  config_mod cfg;


  function new(string name = "mod_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(config_mod)::get(this, "", "config_mod", cfg))
      `uvm_fatal("CONFIG ERROR", "No se encontro config_mod para mod_sequencer")
  endfunction 

endclass : mod_sequencer 