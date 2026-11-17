// Convierte cada wishB_item en un ciclo Wishbone sobre wishB_if.
// Ref: V-WB-01, V-WB-02. Dueño: Eric.
class wishB_driver extends uvm_driver #(wishB_item);
  `uvm_component_utils(wishB_driver)

  virtual wishB_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual wishB_if)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "No se encontró vif")
  endfunction

  task run_phase(uvm_phase phase);
    bus_idle();
    wait (vif.rst === 1'b1);
    wait (vif.rst === 1'b0);
    @(vif.driver_cb);
    forever begin
      seq_item_port.get_next_item(req);
      drive(req);
      seq_item_port.item_done();
    end
  endtask

  task drive(wishB_item it);
    int unsigned n = 0;

    repeat (it.delay) @(vif.driver_cb);
    vif.driver_cb.cyc     <= 1;
    vif.driver_cb.stb     <= 0;
    vif.driver_cb.adr     <= it.adr;
    vif.driver_cb.we      <= it.we;
    vif.driver_cb.sel     <= it.sel;
    vif.driver_cb.dat_m2s <= it.dat;
    repeat (it.stb_delay) @(vif.driver_cb);
    vif.driver_cb.stb     <= 1;

    do begin
      @(vif.driver_cb);
      n++;
      if (n > WB_ACK_TIMEOUT_CYCLES)
        `uvm_fatal("WB", $sformatf("Sin ack tras %0d ciclos: %s", n - 1, it.sprint()))
    end while (!vif.driver_cb.ack);

    if (!it.we) it.dat = vif.driver_cb.dat_s2m;
    bus_idle();
  endtask

  task bus_idle();
    vif.driver_cb.cyc     <= 0;
    vif.driver_cb.stb     <= 0;
    vif.driver_cb.we      <= 0;
    vif.driver_cb.sel     <= 0;
    vif.driver_cb.adr     <= 0;
    vif.driver_cb.dat_m2s <= 0;
  endtask

endclass : wishB_driver
