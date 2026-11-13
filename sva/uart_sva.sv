`timescale 1ns/1ps
`include "uart_defines.v"

module uart_sva (
  input logic                         wb_clk_i,
  input logic                         wb_rst_i,
  input logic [`UART_ADDR_WIDTH-1:0]  wb_adr_i,
  input logic [`UART_DATA_WIDTH-1:0]  wb_dat_i,
  input logic [`UART_DATA_WIDTH-1:0]  wb_dat_o,
  input logic [3:0]                   wb_sel_i,
  input logic                         wb_we_i,
  input logic                         wb_stb_i,
  input logic                         wb_cyc_i,
  input logic                         wb_ack_o
);

  default clocking cb @(posedge wb_clk_i); endclocking
  default disable iff (wb_rst_i);

  // La transferencia se mantiene estable durante la espera. Ref: A-WB-01.
  property p_wb_01;
    (wb_cyc_i && wb_stb_i && !wb_ack_o) |=>
      (wb_stb_i && $stable(wb_adr_i) && $stable(wb_we_i) && $stable(wb_sel_i) &&
       (!wb_we_i || $stable(wb_dat_i)));
  endproperty
  A_WB_01: assert property (p_wb_01)
    else $error("Wishbone: el maestro cambió la transferencia antes de recibir ack");
  C_WB_01: cover property (wb_cyc_i && wb_stb_i && !wb_ack_o ##1 wb_ack_o);

  // Los valores desconocidos no deben propagarse tras reset. Ref: A-WB-03.
  property p_wb_03;
    !$isunknown({wb_ack_o, wb_dat_o});
  endproperty
  A_WB_03: assert property (p_wb_03)
    else $error("Wishbone: wb_ack_o o wb_dat_o tiene X o Z");
  C_WB_03: cover property (p_wb_03);

endmodule : uart_sva
