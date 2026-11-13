`timescale 1ns/1ps
`include "uart_defines.v"

interface wishB_if (input logic clk);

  logic rst;
  logic [`UART_ADDR_WIDTH-1:0] adr;
  logic [`UART_DATA_WIDTH-1:0] dat_m2s;
  logic [`UART_DATA_WIDTH-1:0] dat_s2m;
  logic [3:0] sel;
  logic we;
  logic stb;
  logic cyc;
  logic ack;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output adr, dat_m2s, sel, we, stb, cyc;
    input dat_s2m, ack;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst, adr, dat_m2s, dat_s2m, sel, we, stb, cyc, ack;
  endclocking

  modport drv (clocking drv_cb, input rst);
  modport mon (clocking mon_cb);

endinterface : wishB_if
