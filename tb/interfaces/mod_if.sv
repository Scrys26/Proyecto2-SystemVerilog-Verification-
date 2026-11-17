<<<<<<< HEAD
// -----------------------------------------------------------------------------
// mod_if.sv
// Señales de control de módem del UART.
//
//   Salidas del DUT : rts (rts_pad_o), dtr (dtr_pad_o)
//   Entradas del DUT: cts (cts_pad_i), dsr (dsr_pad_i), ri (ri_pad_i), dcd (dcd_pad_i)
//
// La polaridad de estas señales respecto a MCR y MSR es uno de los puntos
// que el plan de pruebas debe aclarar (sección 3.5 del enunciado).
// -----------------------------------------------------------------------------
=======
>>>>>>> 368c4c43f048b6d27090a6cf85bdb0209ec4dce8
`timescale 1ns/1ps

interface mod_if (input logic clk);

<<<<<<< HEAD
  logic rts;
  logic dtr;
=======
>>>>>>> 368c4c43f048b6d27090a6cf85bdb0209ec4dce8
  logic cts;
  logic dsr;
  logic ri;
  logic dcd;
<<<<<<< HEAD
=======
  logic rts;
  logic dtr;
>>>>>>> 368c4c43f048b6d27090a6cf85bdb0209ec4dce8

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output cts, dsr, ri, dcd;
<<<<<<< HEAD
    input  rts, dtr;
=======
    input rts, dtr;
>>>>>>> 368c4c43f048b6d27090a6cf85bdb0209ec4dce8
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
<<<<<<< HEAD
    input rts, dtr, cts, dsr, ri, dcd;
=======
    input cts, dsr, ri, dcd, rts, dtr;
>>>>>>> 368c4c43f048b6d27090a6cf85bdb0209ec4dce8
  endclocking

  modport drv (clocking drv_cb);
  modport mon (clocking mon_cb);

<<<<<<< HEAD
endinterface : mod_if
=======
endinterface : mod_if
>>>>>>> 368c4c43f048b6d27090a6cf85bdb0209ec4dce8
