//Secuenciador del agente serie, básicamente le pasa al driver los items que crea la secuencia.
// Recoge y guarda el cfg y el modelo de registros para que la secuencia los tome de aquí.

class serie_sequencer extends uvm_sequencer #(serie_item);
  `uvm_component_utils(serie_sequencer)

  config_serie   cfg;
  uart_reg_block regmodel;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(config_serie)::get(this, "", "config_serie", cfg))
      `uvm_fatal("CFG", "Serie_sequencer no encontró config_serie en uvm_config_db")
    if (!uvm_config_db#(uart_reg_block)::get(this, "", "regmodel", regmodel))
      `uvm_fatal("CFG", "Serie_sequencer no encontró el modelo de registros en uvm_config_db")
  endfunction

endclass : serie_sequencer