

class int_monitor extends uvm_monitor;

  `uvm_component_utils(int_monitor)

  virtual int_if vif; // Virtual interface 

  uvm_analysis_port #(bit) int_ap; // Analysis port for transactions

  // Constructor
  function new(string name = "int_monitor", uvm_component parent = null);
    super.new(name, parent);
    int_ap = new("int_ap", this);
 endfunction

 function void build_phase(uvm_phase phase );
    super.build_phase(phase);
    if(!uvm_config_db#(virtual int_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("VIF", "No se encontro la interfaz virtual int_if para int_monitor");
    end
  endfunction

task run_phase(uvm_phase phase);
    logic sampled_irq;
    bit current_irq;
    bit previous_irq;
    bit have_previous = 0;
    bit unkown_reported = 0;
    
    forever begin 
        @(vif.mon_cb);
        sampled_irq = vif.mon_cb.int_o;

        if($isunknown(sampled_irq)) begin
            if(!unkown_reported) 
                `uvm_warning("INT_MON", "int_o contiene X/Z")
             unkown_reported = 1;
             have_previous = 0;
             continue;
        end
        unkown_reported = 0;
        current_irq = sampled_irq;
        
        if (!have_previous || current_irq != previous_irq) begin
            int_ap.write(current_irq);
            previous_irq = current_irq;
            have_previous = 1;

            `uvm_info("INT_MON", $sformatf("cambio observado: %0b", current_irq), UVM_MEDIUM)
        end
    end
  endtask
endclass : int_monitor
