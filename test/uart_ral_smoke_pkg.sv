// Paquete de la prueba de humo del RAL; depende de uart_tb_pkg.
// Ref: V-RST-01, V-REG-01, V-REG-03. Dueño: Eric.
`timescale 1ns/1ps

package uart_ral_smoke_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import uart_tb_pkg::*;

  `include "uart_ral_smoke_seq.sv"
  `include "uart_ral_smoke_test.sv"

endpackage : uart_ral_smoke_pkg
