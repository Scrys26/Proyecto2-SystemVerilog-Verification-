// Paquete de la prueba de humo del agente Wishbone; depende de uart_tb_pkg.
// Ref: V-WB-01, V-WB-02. Dueño: Eric.
`timescale 1ns/1ps

package uart_wb_smoke_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import uart_tb_pkg::*;

  `include "wishB_smoke_seq.sv"
  `include "uart_wb_smoke_test.sv"

endpackage : uart_wb_smoke_pkg
