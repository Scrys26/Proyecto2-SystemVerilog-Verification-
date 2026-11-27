// Paquete de la prueba de humo del agente serie; depende de uart_tb_pkg.
`timescale 1ns/1ps

package serie_smoke_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import uart_tb_pkg::*;

  `include "serie_smoke_test.sv"

endpackage : serie_smoke_pkg
