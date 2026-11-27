// Rutas relativas a la raíz del repositorio.
+incdir+rtl/verilog
+incdir+tb
+incdir+tb/interfaces
+incdir+tb/agents/wishB
+incdir+tb/agents/serie
+incdir+tb/Scoreboard
+incdir+tb/ral
+incdir+test
+incdir+sva
+incdir+tb/agents/Modem
+incdir+tb/Monitors
+incdir+tb/Env


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
tb/interfaces/wishB_if.sv
tb/interfaces/serie_if.sv
tb/interfaces/mod_if.sv
tb/interfaces/int_if.sv
sva/uart_sva.sv
sva/uart_sva_bind.sv
sva/uart_modem_sva.sv

// ---- Ambiente UVM: después del RTL para que las macros de uart_defines.v ya existan ----
tb/ral/dlab0_rm_pkg.sv
tb/ral/dlab1_rm_pkg.sv
tb/uart_tb_pkg.sv

// ---- Prueba de humo (reemplazar al agregar el ambiente UVM) ----
test/uart_hello_pkg.sv
test/uart_wb_smoke_pkg.sv
test/uart_ral_smoke_pkg.sv
test/serie_smoke_pkg.sv 

// ---- Top ----
tb/tb_top.sv
