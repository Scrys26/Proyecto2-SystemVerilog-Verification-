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
  `include "uart_ral.sv"
  `include "uart_ral_env.sv"

endpackage : uart_tb_pkg
