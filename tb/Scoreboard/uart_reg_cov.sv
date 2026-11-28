// Cobertura de los accesos a registros (cg_reg_rst del plan). Se muestrea con cada transacción
// que ve el monitor Wishbone; el DLAB se toma del espejo del RAL.

class uart_reg_cov extends uvm_subscriber #(wishB_item);
  `uvm_component_utils(uart_reg_cov)

  // Los asigna el ambiente con lo que ya tiene el RAL
  uart_ral_adapter       adapter;
  dlab0_rm_pkg::dlab0_rm regs;

  covergroup cg_reg_rst with function sample(int unsigned addr, bit dlab, bit is_read, bit [3:0] sel);
    // Direcciones 0 a 7 (la 7 es el scratch, AMB-01) y los dos registros de depuración (8 y 12)
    cp_addr : coverpoint addr {
      bins regs[] = {[0:7]};
      bins dbg1   = {8};
      bins dbg2   = {12};
    }
    cp_dlab : coverpoint dlab;
    // Las direcciones 0 y 1 cambian de registro con DLAB (RBR/THR/DLL e IER/DLM): V-REG-01
    x_addr_dlab : cross cp_addr, cp_dlab {
      ignore_bins dbg = binsof(cp_addr.dbg1) || binsof(cp_addr.dbg2);
    }
    cp_reg_access : coverpoint is_read {
      bins write = {0};
      bins read  = {1};
    }
    // Lecturas con efecto lateral: RBR saca de la FIFO, IIR, LSR y MSR limpian cosas (V-REG-02)
    cp_side_effect : coverpoint addr iff (is_read && !(addr == 0 && dlab)) {
      bins rbr = {0};
      bins iir = {2};
      bins lsr = {5};
      bins msr = {6};
    }
    // Lecturas de depuración de 32 bits (V-REG-04)
    cp_debug_read : coverpoint addr iff (is_read && sel == 4'b1111) {
      bins dbg1 = {8};
      bins dbg2 = {12};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_reg_rst = new();
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    if (adapter == null || regs == null)
      `uvm_fatal("COV", "uart_reg_cov sin adaptador o sin modelo de registros")
  endfunction

  function void write(wishB_item t);
    uvm_reg_bus_op rw;
    adapter.bus2reg(t, rw);
    cg_reg_rst.sample(32'(rw.addr), 1'(regs.LCR.dlab.get_mirrored_value()), rw.kind == UVM_READ, t.sel);
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("Cobertura de registros: reg_rst %0.1f%%", cg_reg_rst.get_inst_coverage()), UVM_LOW)
  endfunction

endclass : uart_reg_cov
