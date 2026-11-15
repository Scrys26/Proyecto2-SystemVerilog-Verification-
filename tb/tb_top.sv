`timescale 1ns/1ps

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import uart_hello_pkg::*;

  parameter real CLK_PERIOD_NS = 20.0;

  logic clk = 1'b0;
  always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

  wishB_if wishB_bus (clk);
  serie_if serie_line (clk);
  mod_if mod_signals (clk);
  int_if int_signals (clk);

  initial begin
    wishB_bus.rst     = 1'b1;
    wishB_bus.cyc     = 1'b0;
    wishB_bus.stb     = 1'b0;
    wishB_bus.we      = 1'b0;
    wishB_bus.sel     = '0;
    wishB_bus.adr     = '0;
    wishB_bus.dat_m2s = '0;
    serie_line.srx    = 1'b1;
    mod_signals.cts   = 1'b1;
    mod_signals.dsr   = 1'b1;
    mod_signals.ri    = 1'b1;
    mod_signals.dcd   = 1'b1;
    repeat (5) @(posedge clk);
    wishB_bus.rst = 1'b0;
  end

  uart_top dut (
    .wb_clk_i  (clk),
    .wb_rst_i  (wishB_bus.rst),
    .wb_adr_i  (wishB_bus.adr),
    .wb_dat_i  (wishB_bus.dat_m2s),
    .wb_dat_o  (wishB_bus.dat_s2m),
    .wb_we_i   (wishB_bus.we),
    .wb_stb_i  (wishB_bus.stb),
    .wb_cyc_i  (wishB_bus.cyc),
    .wb_ack_o  (wishB_bus.ack),
    .wb_sel_i  (wishB_bus.sel),
    .int_o     (int_signals.int_o),
    .stx_pad_o (serie_line.stx),
    .srx_pad_i (serie_line.srx),
    .rts_pad_o (mod_signals.rts),
    .cts_pad_i (mod_signals.cts),
    .dtr_pad_o (mod_signals.dtr),
    .dsr_pad_i (mod_signals.dsr),
    .ri_pad_i  (mod_signals.ri),
    .dcd_pad_i (mod_signals.dcd)
`ifdef UART_HAS_BAUDRATE_OUTPUT
   ,.baud_o    (serie_line.baud)
`endif
  );

`ifndef UART_HAS_BAUDRATE_OUTPUT
  assign serie_line.baud = 1'b0;
`endif

  initial begin
    uvm_config_db#(virtual wishB_if)::set(null, "uvm_test_top*", "vif", wishB_bus);
    uvm_config_db#(virtual serie_if)::set(null, "uvm_test_top*", "vif", serie_line);
    uvm_config_db#(virtual mod_if)::set(null, "uvm_test_top*", "vif", mod_signals);
    uvm_config_db#(virtual int_if)::set(null, "uvm_test_top*", "vif", int_signals);
    run_test();
  end

`ifdef DUMP_FSDB
  initial begin
    $fsdbDumpfile("waves.fsdb");
    $fsdbDumpvars(0, tb_top);
  end
`endif

endmodule : tb_top
