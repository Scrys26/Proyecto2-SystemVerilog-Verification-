// Paquete único del ambiente: constantes compartidas e includes de las clases en orden de dependencia.
// Ref: V-WB-01, V-WB-02. Dueño: Eric.
`timescale 1ns/1ps

package uart_tb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // holgado, el driver solo evita colgarse, la aserción reporta si debemos aumentarlo.
  localparam int unsigned WB_ACK_TIMEOUT_CYCLES = 16;

  `include "wishB_item.sv"
  `include "config_wishB.sv"
  `include "wishB_sequencer.sv"
  `include "wishB_driver.sv"
  `include "wishB_monitor.sv"
  `include "wishB_agent.sv"
  `include "uart_ral_env.sv"
  `include "config_serie.sv"
  `include "serie_item.sv"
  `include "serie_sequencer.sv"
  `include "serie_driver.sv"
  `include "serie_monitor.sv"
  `include "serie_agent.sv"
  `include "serie_rx_seq.sv"
  `include "serie_tx_seq.sv"
  `include "uart_serie_model.sv"
  `include "uart_serie_sb.sv"
  `include "uart_serie_cov.sv"

  `include "config_mod.sv"
  `include "mod_pin_event.sv"
  `include "mod_sequencer.sv"
  `include "mod_pin_driver.sv"
  `include "mod_monitor.sv"
  `include "mod_agent.sv"
  `include "mod_seq.sv"

  `include "int_monitor.sv"

  `include "uart_int_model.sv"
  `include "uart_msr_model.sv"
  `include "uart_modem_irq_cov.sv"
  `include "uart_modem_irq_sb.sv"

  `include "uart_env_cfg.sv"
  `include "uart_virtual_sequencer.sv"
  `include "uart_env.sv"
  `include "uart_main_vseq.sv"
  `include "uart_base_test.sv"

  
endpackage : uart_tb_pkg