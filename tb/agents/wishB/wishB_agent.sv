// Agente Wishbone: monitor siempre; secuenciador y driver solo en modo activo.
// Ref: V-WB-01, V-WB-02. Dueño: Eric.
class wishB_agent extends uvm_agent;
  `uvm_component_utils(wishB_agent)

  config_wishB    cfg;
  wishB_sequencer sqr;
  wishB_driver    drv;
  wishB_monitor   mon;
  uvm_analysis_port #(wishB_item) wishB_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(config_wishB)::get(this, "", "config_wishB", cfg))
      `uvm_fatal("CFG", "No se encontró config_wishB")
    // Se copia para que get_is_active() coincida con config_wishB.
    is_active = cfg.is_active;

    mon = wishB_monitor::type_id::create("mon", this);
    if (is_active == UVM_ACTIVE) begin
      sqr = wishB_sequencer::type_id::create("sqr", this);
      drv = wishB_driver::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    wishB_ap = mon.wishB_ap;
    if (is_active == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass : wishB_agent