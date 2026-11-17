// Interfaz Wishbone Rev. B entre el agente wishB y el 
// esclavo uart_top.
// Ref: F-WB-01, V-WB-01, V-WB-02. Dueño: Eric.
`timescale 1ns/1ps
`include "uart_defines.v"

interface wishB_if (input logic clk);

  // Los anchos salen de uart_defines.v para que +define+DATA_BUS_WIDTH_8 no requiera cambios aquí.
  logic                         rst;
  // señales del bus
  logic [`UART_ADDR_WIDTH-1:0]  adr;
  logic [`UART_DATA_WIDTH-1:0]  dat_m2s;
  logic [`UART_DATA_WIDTH-1:0]  dat_s2m;
  // wb_sel_i es de 4 bits en ambos modos (uart_top.v:171) en 8 bits el DUT lo ignora (uart_top.v:236).
  logic [3:0]                   sel;
  logic                         we;
  logic                         stb;
  logic                         cyc;
  logic                         ack;

  // El driver escribe después del flanco para no competir con el muestreo del DUT.
  clocking driver_cb @(posedge clk);
    default input #1step output #1;
    output adr, dat_m2s, sel, we, stb, cyc;
    input  dat_s2m, ack;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1step;
    input rst, adr, dat_m2s, dat_s2m, sel, we, stb, cyc, ack;
  endclocking

  // rst es asíncrono: el driver lo lee fuera del 
  // clocking block para reaccionar sin esperar un flanco.
  modport driver (clocking driver_cb, input rst);
  modport monitor (clocking monitor_cb);

endinterface : wishB_if
