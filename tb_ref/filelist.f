// Lista de archivos para VCS. Las rutas son relativas a la raiz del repositorio.
// uart_defines.v y timescale.v no se listan: los incluyen los propios archivos
// (por eso hace falta +incdir+rtl/verilog).

+incdir+rtl/verilog
+incdir+tb
+incdir+tb/interfaces
+incdir+test
+incdir+sva

// ---- RTL del DUT (no modificar) ----
rtl/verilog/raminfr.v
rtl/verilog/uart_sync_flops.v
rtl/verilog/uart_tfifo.v
rtl/verilog/uart_rfifo.v
rtl/verilog/uart_transmitter.v
rtl/verilog/uart_receiver.v
rtl/verilog/uart_regs.v
rtl/verilog/uart_debug_if.v
rtl/verilog/uart_wb.v
rtl/verilog/uart_top.v

// ---- Interfaces y aserciones ----
tb/interfaces/wb_if.sv
tb/interfaces/uart_ser_if.sv
tb/interfaces/modem_if.sv
sva/uart_wb_sva.sv
sva/uart_bind.sv

// ---- Prueba de humo (reemplazar al agregar el ambiente UVM) ----
test/uart_hello_pkg.sv

// ---- Top ----
tb/tb_top.sv
