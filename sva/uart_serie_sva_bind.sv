// Enlaza las aserciones de la línea serie con uart_top. Los registros internos se toman de la instancia regs.
bind uart_top uart_serie_sva u_uart_serie_sva (
  .wb_clk_i  (wb_clk_i),
  .wb_rst_i  (wb_rst_i),
  .stx_pad_o (stx_pad_o),
  .lcr       (regs.lcr),
  .dl        (regs.dl),
  .loopback  (regs.mcr[4]),
  .tx_empty  (regs.lsr6)
);
