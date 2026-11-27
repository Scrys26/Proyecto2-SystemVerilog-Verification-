`timescale 1ns/1ps

// Aserciones de la línea serie: revisan stx con las reglas del UART.
// Se enlaza a uart_top con bind para poder ver los registros internos de formato y loopback.
module uart_serie_sva #(
  parameter int unsigned OVERSAMPLE = 16
) (
  input logic        wb_clk_i,
  input logic        wb_rst_i,
  input logic        stx_pad_o,
  input logic [7:0]  lcr,
  input logic [15:0] dl,
  input logic        loopback,
  input logic        tx_empty
);

  default clocking cb @(posedge wb_clk_i); endclocking
  default disable iff (wb_rst_i);

  // Cuánto dura un bit en ciclos de reloj con el divisor actual
  int unsigned bit_clks;
  assign bit_clks = OVERSAMPLE * dl;

  // Cuenta cuántos ciclos lleva stx en 0. Si en medio hubo break, loopback o cambio de divisor,
  // ese tramo no se revisa porque su largo ya no depende solo del divisor.
  int unsigned low_cnt;
  bit          low_valid;

  always_ff @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      low_cnt   <= 0;
      low_valid <= 1'b0;
    end else if (stx_pad_o) begin
      low_cnt   <= 0;
      low_valid <= 1'b1;
    end else begin
      low_cnt <= low_cnt + 1;
      if (lcr[6] || loopback || $changed(dl) || dl == 0)
        low_valid <= 1'b0;
    end
  end

  // A-SER-01: sin nada que transmitir y sin break, la línea queda en reposo (1)
  property p_ser_01;
    (tx_empty && !lcr[6]) |-> stx_pad_o;
  endproperty
  A_SER_01: assert property (p_ser_01)
    else $error("Serie: stx no está en reposo aunque no hay nada que transmitir");
  C_SER_01: cover property (tx_empty && !lcr[6] && stx_pad_o);

  // A-SER-02: cada bit dura 16 x DL ciclos. Un tramo en 0 son uno o varios bits seguidos,
  // así que su largo tiene que ser múltiplo exacto del tiempo de bit.
  property p_ser_02;
    ($rose(stx_pad_o) && low_valid && dl != 0) |-> (low_cnt % bit_clks == 0);
  endproperty
  A_SER_02: assert property (p_ser_02)
    else $error("Serie: un tramo en 0 de stx duró %0d ciclos, que no es múltiplo de %0d", low_cnt, bit_clks);
  C_SER_02: cover property ($rose(stx_pad_o) && low_valid && dl != 0);

  // A-SER-03: con break activo (LCR[6]) y sin loopback, stx queda en 0
  property p_ser_03;
    (lcr[6] && !loopback) |-> !stx_pad_o;
  endproperty
  A_SER_03: assert property (p_ser_03)
    else $error("Serie: hay break activo pero stx no está en 0");
  C_SER_03: cover property (lcr[6] && !loopback && !stx_pad_o);

  // A-LB-01: en loopback, stx se queda en 1 porque lo transmitido vuelve por dentro
  property p_lb_01;
    loopback |-> stx_pad_o;
  endproperty
  A_LB_01: assert property (p_lb_01)
    else $error("Serie: en loopback stx debería quedarse en 1");
  C_LB_01: cover property (loopback && stx_pad_o);

endmodule : uart_serie_sva
