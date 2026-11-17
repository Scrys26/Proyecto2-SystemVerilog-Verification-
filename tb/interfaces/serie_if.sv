`timescale 1ns/1ps

interface serie_if (input logic clk);

  logic stx;
  logic srx;
  logic baud;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output srx;
    input stx;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input stx, srx, baud;
  endclocking

  modport drv (clocking drv_cb);
  modport mon (clocking mon_cb);

endinterface : serie_if
