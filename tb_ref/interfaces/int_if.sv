`timescale 1ns/1ps

interface int_if (input logic clk);

  logic int_o;

  clocking mon_cb @(posedge clk);
    default input #1step;
    input int_o;
  endclocking

  modport mon (clocking mon_cb);

endinterface : int_if
