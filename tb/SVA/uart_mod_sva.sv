
`timescale 1ns/1ps
`include "uart_defines.v"

module uart_modem_sva (
  input logic wb_clk_i,
  input logic wb_rst_i,
  input logic [`UART_ADDR_WIDTH-1:0] wb_adr_i,
  input logic [`UART_DATA_WIDTH-1:0] wb_dat_i,
  input logic [3:0] wb_sel_i,
  input logic wb_we_i,
  input logic wb_stb_i,
  input logic wb_cyc_i,
  input logic wb_ack_o,
  input logic stx_pad_o,
  input logic rts_pad_o,
  input logic dtr_pad_o,
  input logic cts_pad_i,
  input logic dsr_pad_i,
  input logic ri_pad_i,
  input logic dcd_pad_i,
  input logic int_o
);

  logic [4:0] mcr_expected;
  logic [4:0] mcr_write_value;
  logic mcr_write_ack;

  integer byte_lane;
  integer reg_addr;

  // Guardamos los bits de MCR a partir de Wishbone.
  always_comb begin
    mcr_write_ack = 1'b0;
    mcr_write_value = 5'b0;
    byte_lane = -1;
    reg_addr = -1;

`ifdef DATA_BUS_WIDTH_8
    reg_addr = int'(wb_adr_i);
    mcr_write_value = wb_dat_i[4:0];

    mcr_write_ack = wb_cyc_i && wb_stb_i && wb_we_i &&
                    wb_ack_o && (reg_addr == 4);
`else

    case (wb_sel_i)
      4'b0001: byte_lane = 0;
      4'b0010: byte_lane = 1;
      4'b0100: byte_lane = 2;
      4'b1000: byte_lane = 3;
      default: byte_lane = -1;
    endcase

    if (byte_lane >= 0) begin

`ifdef LITLE_ENDIAN
      reg_addr = (int'(wb_adr_i) & ~3) | byte_lane;
`else
      reg_addr = (int'(wb_adr_i) & ~3) | (3 - byte_lane);
`endif

      mcr_write_value =
        (wb_dat_i >> (8 * byte_lane)) & 5'h1f;

      mcr_write_ack = wb_cyc_i && wb_stb_i && wb_we_i &&
                      wb_ack_o && (reg_addr == 4);
    end
`endif
  end

  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
      mcr_expected <= 5'b0;
    else if (mcr_write_ack)
      mcr_expected <= mcr_write_value;
  end

  default clocking cb @(posedge wb_clk_i); endclocking
  default disable iff (wb_rst_i);

  // Revisamos que RTS siga el bit de MCR.
  A_MOD_RTS: assert property (
    !mcr_write_ack |-> (rts_pad_o === mcr_expected[1])
  ) else $error("MOD_SVA: RTS no coincide con MCR[1]");

  // Revisamos que DTR siga el bit de MCR.
  A_MOD_DTR: assert property (
    !mcr_write_ack |-> (dtr_pad_o === mcr_expected[0])
  ) else $error("MOD_SVA: DTR no coincide con MCR[0]");

  // En loopback la salida TX debe quedar en alto.
  A_LB_01: assert property (
    (mcr_expected[4] && !mcr_write_ack) |->
      (stx_pad_o === 1'b1)
  ) else $error("MOD_SVA: TX no esta en alto durante loopback");

  // Las salidas principales no deben tener X ni Z.
  A_MOD_KNOWN: assert property (
    !$isunknown({rts_pad_o, dtr_pad_o, int_o})
  ) else $error("MOD_SVA: salida de modem o interrupcion con X/Z");

  C_MOD_KNOWN: cover property (
    !$isunknown({rts_pad_o, dtr_pad_o, int_o})
  );

  C_MOD_RTS: cover property ($changed(rts_pad_o));
  C_MOD_DTR: cover property ($changed(dtr_pad_o));

  C_MOD_CTS: cover property ($changed(cts_pad_i));
  C_MOD_DSR: cover property ($changed(dsr_pad_i));
  C_MOD_RI:  cover property ($changed(ri_pad_i));
  C_MOD_DCD: cover property ($changed(dcd_pad_i));

  C_LB_ENTER: cover property ($rose(mcr_expected[4]));

  C_LB_01: cover property (
    mcr_expected[4] &&
    !mcr_write_ack &&
    stx_pad_o === 1'b1
  );

  C_INT_RISE: cover property ($rose(int_o));

endmodule : uart_modem_sva


// Enlazamos las aserciones a los puertos del UART.
bind uart_top uart_modem_sva u_uart_modem_sva (
  .wb_clk_i  (wb_clk_i),
  .wb_rst_i  (wb_rst_i),

  .wb_adr_i  (wb_adr_i),
  .wb_dat_i  (wb_dat_i),
  .wb_sel_i  (wb_sel_i),
  .wb_we_i   (wb_we_i),
  .wb_stb_i  (wb_stb_i),
  .wb_cyc_i  (wb_cyc_i),
  .wb_ack_o  (wb_ack_o),

  .stx_pad_o (stx_pad_o),
  .rts_pad_o (rts_pad_o),
  .dtr_pad_o (dtr_pad_o),

  .cts_pad_i (cts_pad_i),
  .dsr_pad_i (dsr_pad_i),
  .ri_pad_i  (ri_pad_i),
  .dcd_pad_i (dcd_pad_i),

  .int_o     (int_o)
);
