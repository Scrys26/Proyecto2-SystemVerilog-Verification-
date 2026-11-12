`timescale 1ns/1ps
interface mod_if(input logic clk);

    logic cts;
    logic dsr;
    logic ri;
    logic dcd;
    logic rts;
    logic dtr;

    clocking drv_cb @(posedge clk);
        default input #1step output #1;
        
        output cts;
        output dsr;
        output ri;
        output dcd;
        
        input rts;
        input dtr;

    endclocking 

    clocking mon_cb @(posedge clk);
        default input #1step;
        
        input cts;
        input dsr;
        input ri;
        input dcd;
        
        input rts;
        input dtr;
    endclocking

    modport drv(clocking drv_cb);
    modport mon(clocking mon_cb);
    
endinterface : mod_if