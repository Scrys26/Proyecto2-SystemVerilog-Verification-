class mod_monitor extends uvm_monitor;
    `uvm_component_utils(mod_monitor)


    virtual mod_if vif;
    config_mod cfg;

    uvm_analysis_port #(mod_pin_event) mod_ap;

    function new(string name = "mod_monitor", uvm_component parent = null);
        super.new(name,parent);
        mod_ap = new("mod_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual mod_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("VIF", "no se encontro la interfaz virtual mod_if para mod_monitor");
        end
        if(!uvm_config_db#(config_mod)::get(this, "", "config_mod", cfg)) begin
            `uvm_fatal("CFG", "no se encontro el config_mod para mod_monitor");
        end
    endfunction

    task run_phase(uvm_phase phase);
        logic [5:0] current_pins;
        logic [5:0] previous_pins;

        bit have_previous = 0;
        int unsigned cycle_since_change = 0;
        mod_pin_event observed;

        forever begin 
            @(vif.mon_cb);
            current_pins = {vif.mon_cb.cts, vif.mon_cb.dsr, 
                            vif.mon_cb.ri,  vif.mon_cb.dcd,  
                            vif.mon_cb.rts, vif.mon_cb.dtr};
            if (!have_previous|| current_pins != previous_pins) begin
            observed = mod_pin_event::type_id::create("observed");
            observed.pin_inputs = current_pins[5:2];
            observed.pin_outputs = current_pins[1:0];
            observed.idle_clocks = have_previous ? cycle_since_change + 1: 0;

            mod_ap.write(observed);
            previous_pins = current_pins;
            have_previous = 1;
            cycle_since_change = 0;

            `uvm_info("MON", $sformatf(
                "CTS=%0b, DSR=%0b, RI=%0b, DCD=%0b, RTS=%0b, DTR=%0b",
                observed.pin_inputs[3], observed.pin_inputs[2],
                observed.pin_inputs[1], observed.pin_inputs[0],
                observed.pin_outputs[1], observed.pin_outputs[0]), UVM_LOW)
            end
            else begin
                cycle_since_change++;
            end
        end
    endtask
endclass : mod_monitor