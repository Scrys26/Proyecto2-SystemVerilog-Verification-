// Agente serie: crea el secuenciador, el driver y los dos monitores, y los conecta.
// Si el agente es pasivo solo quedan los monitores, que nada más escuchan.

class serie_agent extends uvm_agent;
  `uvm_component_utils(serie_agent)

  serie_sequencer sqr;
  serie_driver    drv;
  serie_monitor   tx_mon;
  serie_monitor   rx_mon;

  // Los puertos de los monitores se sacan hacia afuera para que el scoreboard se conecte aquí
  uvm_analysis_port #(serie_item) serie_tx_ap;
  uvm_analysis_port #(serie_item) serie_rx_ap;
  uvm_analysis_port #(serie_item) serie_tx_start_ap; // bit de inicio en stx

  function new(string name, uvm_component parent);
    super.new(name, parent);
    serie_tx_ap = new("serie_tx_ap", this);
    serie_rx_ap = new("serie_rx_ap", this);
    serie_tx_start_ap = new("serie_tx_start_ap", this);
  endfunction

  // Los monitores van siempre; el driver y el secuenciador solo si el agente maneja la línea
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_mon     = serie_monitor::type_id::create("tx_mon", this);
    rx_mon     = serie_monitor::type_id::create("rx_mon", this);
    tx_mon.dir = SER_DIR_TX;
    rx_mon.dir = SER_DIR_RX;
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = serie_sequencer::type_id::create("sqr", this);
      drv = serie_driver::type_id::create("drv", this);
    end
  endfunction

  // El driver le pide items al secuenciador, y cada monitor publica por su puerto
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    tx_mon.ap.connect(serie_tx_ap);
    rx_mon.ap.connect(serie_rx_ap);
    tx_mon.start_ap.connect(serie_tx_start_ap);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass : serie_agent