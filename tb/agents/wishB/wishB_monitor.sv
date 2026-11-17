// Publica por wishB_ap cada transferencia Wishbone completada (cyc && stb && ack).
// Ref: V-WB-01, V-WB-02. Dueño: Eric.
class wishB_monitor extends uvm_monitor;
  `uvm_component_utils(wishB_monitor)

  virtual wishB_if vif;
  uvm_analysis_port #(wishB_item) wishB_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual wishB_if)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "No se encontró vif")
    wishB_ap = new("wishB_ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    wishB_item   it;
    int unsigned lat = 0;

    wait (vif.rst === 1'b1);
    wait (vif.rst === 1'b0);
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.cyc && vif.monitor_cb.stb) begin
        lat++;
        if (vif.monitor_cb.ack) begin
          // Un objeto nuevo por transferencia los suscriptores guardan la referencia.
          it         = wishB_item::type_id::create("it");
          it.adr     = vif.monitor_cb.adr;
          it.we      = vif.monitor_cb.we;
          it.sel     = vif.monitor_cb.sel;
          it.dat     = vif.monitor_cb.we ? vif.monitor_cb.dat_m2s : vif.monitor_cb.dat_s2m;
          it.ack_lat = lat;
          wishB_ap.write(it);
          `uvm_info("WB", $sformatf("%s adr=0x%0h sel=%b dat=0x%0h ack_lat=%0d",
                    it.we ? "WR" : "RD", it.adr, it.sel, it.dat, it.ack_lat), UVM_HIGH)
          lat = 0;
        end
      end
      else lat = 0;
    end
  endtask

endclass : wishB_monitor