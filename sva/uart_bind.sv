bind uart_top uart_wb_sva u_wb_sva (
  .wb_clk_i (wb_clk_i),
  .wb_rst_i (wb_rst_i),
  .wb_adr_i (wb_adr_i),
  .wb_dat_i (wb_dat_i),
  .wb_sel_i (wb_sel_i),
  .wb_we_i  (wb_we_i),
  .wb_stb_i (wb_stb_i),
  .wb_cyc_i (wb_cyc_i),
  .wb_ack_o (wb_ack_o)
);
