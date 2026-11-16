class mod_agent extends uvm_agent;
    `uvm_component_utils(mod_agent)

    mod_monitor pin_mon;
    mod_sequencer pin_seqr;
    mod_pin_driver pin_drv;


    function new(string name = "mod_agent", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        pin_mon = mod_monitor::type_id::create("pin_mon", this);

        if (get_is_active() == UVM_ACTIVE) begin
            pin_seqr = mod_sequencer::type_id::create("pin_seqr", this);
            pin_drv = mod_pin_driver::type_id::create("pin_drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            pin_drv.seq_item_port.connect(pin_seqr.seq_item_export);
        end
    endfunction
endclass : mod_agent