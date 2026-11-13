// -----------------------------------------------------------------------------
// uart_hello_pkg.sv
// Prueba de humo para validar que el DUT quedó bien instanciado y que las
// interfaces virtuales llegan al ambiente por uvm_config_db.
//
// IMPORTANTE: esta prueba accede a la interfaz directamente desde el test
// solo para comprobar la instancia. En el proyecto, el acceso al bus lo
// hace el driver del agente Wishbone (o el RAL a través del adaptador).
// No la usen como base del ambiente.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

package uart_hello_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class uart_hello_test extends uvm_test;
    `uvm_component_utils(uart_hello_test)

    virtual wishB_if wishB_vif;
    virtual serie_if serie_vif;
    virtual mod_if mod_vif;
    virtual int_if int_vif;

    function new(string name = "uart_hello_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual wishB_if)::get(this, "", "vif", wishB_vif))
        `uvm_fatal("NOVIF", "No se encontró la interfaz Wishbone en uvm_config_db")
      if (!uvm_config_db#(virtual serie_if)::get(this, "", "vif", serie_vif))
        `uvm_fatal("NOVIF", "No se encontró la interfaz serie en uvm_config_db")
      if (!uvm_config_db#(virtual mod_if)::get(this, "", "vif", mod_vif))
        `uvm_fatal("NOVIF", "No se encontró la interfaz de módem en uvm_config_db")
      if (!uvm_config_db#(virtual int_if)::get(this, "", "vif", int_vif))
        `uvm_fatal("NOVIF", "No se encontró la interfaz de interrupción en uvm_config_db")
    endfunction

    // Lectura Wishbone de un registro de 8 bits.
    //   reg_addr: índice del registro de la especificación (0 = RBR ... 6 = MSR).
    // En modo de 32 bits sin LITLE_ENDIAN, el byte se selecciona con
    // wb_sel_i = 4'b1000 >> reg_addr[1:0] y viaja en el carril 3 - reg_addr[1:0].
    task automatic wishB_read(input bit [4:0] reg_addr, output bit [7:0] read_data);
      int byte_lane;
      @(wishB_vif.drv_cb);
      wishB_vif.drv_cb.adr <= reg_addr;
`ifdef DATA_BUS_WIDTH_8
      wishB_vif.drv_cb.sel <= 4'b0001;
      byte_lane = 0;
`else
      wishB_vif.drv_cb.sel <= 4'b1000 >> reg_addr[1:0];
      byte_lane = 3 - reg_addr[1:0];
`endif
      wishB_vif.drv_cb.we  <= 1'b0;
      wishB_vif.drv_cb.cyc <= 1'b1;
      wishB_vif.drv_cb.stb <= 1'b1;
      do @(wishB_vif.drv_cb); while (wishB_vif.drv_cb.ack !== 1'b1);
      read_data = wishB_vif.drv_cb.dat_s2m[8*byte_lane +: 8];
      wishB_vif.drv_cb.cyc <= 1'b0;
      wishB_vif.drv_cb.stb <= 1'b0;
    endtask

    task run_phase(uvm_phase phase);
      bit [7:0] lcr_value, iir_value, lsr_value;
      phase.raise_objection(this);

      // Esperar a que termine el reset que genera tb_top.
      wait (wishB_vif.rst === 1'b0);
      repeat (2) @(wishB_vif.drv_cb);

      wishB_read(5'd3, lcr_value);
      wishB_read(5'd2, iir_value);
      wishB_read(5'd5, lsr_value);

      `uvm_info("HELLO", $sformatf("LCR = 0x%02h, IIR = 0x%02h, LSR = 0x%02h", lcr_value, iir_value, lsr_value), UVM_LOW)

      // Según la especificación, LCR se reinicia en 8'b0000_0011.
      if (lcr_value !== 8'h03)
        `uvm_error("HELLO", $sformatf("LCR después de reset = 0x%02h, se esperaba 0x03", lcr_value))
      else
        `uvm_info("HELLO", "Instancia correcta: el DUT responde por Wishbone", UVM_LOW)

      if (serie_vif.stx !== 1'b1)
        `uvm_error("HELLO", "stx_pad_o debería estar en reposo (1) después de reset")

      repeat (10) @(wishB_vif.drv_cb);
      phase.drop_objection(this);
    endtask

  endclass : uart_hello_test

endpackage : uart_hello_pkg
