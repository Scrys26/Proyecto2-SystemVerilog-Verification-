`timescale 1ns/1ps

interface serie_if (input logic clk);

  logic stx;
  logic srx;
  logic baud;

  // Pulsos internos del DUT, de un ciclo, que maneja tb_top. Solo los miran los monitores serie:
  // tx_pop cuando el transmisor saca un byte de la FIFO TX y rx_push cuando entra uno a la FIFO RX.
  // Hacen falta porque en loopback esos bytes nunca pasan por stx ni srx.
  logic tx_pop;
  logic rx_push;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output srx;
    input stx;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input stx, srx, baud, tx_pop, rx_push;
  endclocking

  modport drv (clocking drv_cb);
  modport mon (clocking mon_cb);

endinterface : serie_if
