`timescale 1ns/1ps

interface mod_if (input logic clk);

  logic cts;
  logic dsr;
  logic ri;
  logic dcd;
  logic rts;
  logic dtr;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output cts, dsr, ri, dcd;
    input rts, dtr;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input cts, dsr, ri, dcd, rts, dtr;
  endclocking

  modport drv (clocking drv_cb);
  modport mon (clocking mon_cb);

endinterface : mod_if