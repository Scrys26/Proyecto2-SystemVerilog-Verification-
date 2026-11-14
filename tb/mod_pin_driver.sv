class mod_pin_driver extends uvm_driver #(mod_pin_event);
    `uvm_component_utils(mod_pin_driver)
     virtual mod_if vif;
     config_mod cfg;

     function new (string name = "mod_pin_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(config_mod)::get(this, "", "config_mod", cfg))
            `uvm_fatal("CFG", "no se encontro la configuracion de mod_pin_driver")

        if (!uvm_config_db#(virtual mod_if)::get(this,"","vif", vif))
            `uvm_fatal("CFG", "no se encontro la interfaz virtual mod_if")
    endfunction
    
    task run_phase(uvm_phase phase);
        @(vif.drv_cb);

        vif.drv_cb.cts <= 1'b1;
        vif.drv_cb.dsr <= 1'b1;
        vif.drv_cb.ri  <= 1'b1;
        vif.drv_cb.dcd <= 1'b1;

        forever begin
            seq_item_port.get_next_item(req);
            drive_pins(req);
            seq_item_port.item_done();
        end
    endtask 

    task drive_pins(mod_pin_event item);

        repeat (item.idle_clocks ) @(vif.drv_cb);
        @(vif.drv_cb);

        vif.drv_cb.cts <= item.pin_inputs[3];
        vif.drv_cb.dsr <= item.pin_inputs[2];
        vif.drv_cb.ri  <= item.pin_inputs[1];
        vif.drv_cb.dcd <= item.pin_inputs[0];

        `uvm_info("DRV", $sformatf("Driving pins: CTS=%0b, DSR=%0b, RI=%b, DCD=%b, espera=%0ciclos extra", 
            item.pin_inputs[3], item.pin_inputs[2], item.pin_inputs[1], item.pin_inputs[0], item.idle_clocks),
             UVM_LOW)
    endtask
endclass : mod_pin_driver




