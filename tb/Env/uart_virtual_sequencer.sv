
class uart_virtual_sequencer
  extends uvm_sequencer #(uvm_sequence_item);

  `uvm_component_utils(uart_virtual_sequencer)

  // Secuenciadores de los tres agentes.
  wishB_sequencer wb_sqr;
  serie_sequencer ser_sqr;
  mod_sequencer   modem_sqr;

  // Acceso al RAL y configuracion global.
  uart_ral_env ral;
  uart_env_cfg cfg;

  function new(
    string name = "uart_virtual_sequencer",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

endclass : uart_virtual_sequencer
