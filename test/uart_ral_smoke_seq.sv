// Prueba de humo del RAL: rutas de puerta trasera, reset por ambas puertas y escritura que llega al registro.
// Ref: V-RST-01, V-REG-01, V-REG-03. Dueño: Eric.
class uart_ral_smoke_seq extends uvm_sequence #(wishB_item);
  `uvm_object_utils(uart_ral_smoke_seq)

  // Lo asigna la prueba antes de start().
  uart_ral_env ral;

  bit [7:0]  scr_wdata = 8'h5A;
  bit [15:0] dl_wdata  = 16'h1234;

  function new(string name = "uart_ral_smoke_seq");
    super.new(name);
  endfunction

  task body();
    uvm_reg_mem_hdl_paths_seq paths_seq;
    uvm_reg_hw_reset_seq      rst_seq;
    uvm_status_e              st;
    uvm_reg_data_t            v;

    // 1. Cada ruta de puerta trasera existe en el diseño (incluida la selección de bits dl[15:8]).
    `uvm_info("RAL", "Paso 1: rutas de puerta trasera", 200)
    paths_seq = uvm_reg_mem_hdl_paths_seq::type_id::create("paths_seq");
    paths_seq.model = ral.regs;
    paths_seq.start(m_sequencer, this);
    paths_seq.model = ral.dl_regs;
    paths_seq.start(m_sequencer, this);

    // 2. Reset por puerta delantera. Solo dlab0_rm: con DLAB = 0, las direcciones 0 y 1 son RBR e IER.
    `uvm_info("RAL", "Paso 2: reset por puerta delantera (uvm_reg_hw_reset_seq sobre dlab0_rm)", 200)
    rst_seq = uvm_reg_hw_reset_seq::type_id::create("rst_seq");
    rst_seq.model = ral.regs;
    rst_seq.start(m_sequencer, this);

    // 3. Reset por puerta trasera. La máscara son los bits que cubre la ruta (uart_ral_env::add_backdoor_*).
    `uvm_info("RAL", "Paso 3: reset por puerta trasera", 200)
    check_reset_backdoor(ral.regs.IER,    'h0F);
    check_reset_backdoor(ral.regs.IIR,    'h0F);
    check_reset_backdoor(ral.regs.FCR,    'hC0);
    check_reset_backdoor(ral.regs.LCR,    'hFF);
    check_reset_backdoor(ral.regs.MCR,    'h1F);
    check_reset_backdoor(ral.regs.LSR,    'hFF);
    check_reset_backdoor(ral.regs.SCR,    'hFF);
    check_reset_backdoor(ral.dl_regs.DLL, 'hFF);
    check_reset_backdoor(ral.dl_regs.DLM, 'hFF);

    // 4a. La escritura por el bus llega al registro interno y el predictor actualiza el espejo (V-REG-03).
    `uvm_info("RAL", $sformatf("Paso 4a: escritura de SCR = 0x%02h", scr_wdata), 200)
    ral.regs.SCR.write(st, scr_wdata, .parent(this));
    ral.regs.SCR.peek(st, v);
    expect_eq("SCR por puerta trasera", v, scr_wdata);
    // El driver y el monitor ven el mismo ack: un acceso más garantiza que el predictor ya corrió.
    ral.regs.SCR.read(st, v, .parent(this));
    expect_eq("SCR leído por el bus", v, scr_wdata);
    expect_eq("SCR en el espejo", ral.regs.SCR.get_mirrored_value(), scr_wdata);

    // 4b. Protocolo DLAB: nadie puede intercalarse entre subir y bajar DLAB.
    `uvm_info("RAL", $sformatf("Paso 4b: write_dl(0x%04h) con el secuenciador bloqueado", dl_wdata), 200)
    m_sequencer.lock(this);
    ral.write_dl(dl_wdata, st, this);
    m_sequencer.unlock(this);
    ral.dl_regs.DLL.peek(st, v);
    expect_eq("DLL por puerta trasera", v, dl_wdata[7:0]);
    ral.dl_regs.DLM.peek(st, v);
    expect_eq("DLM por puerta trasera", v, dl_wdata[15:8]);
    ral.regs.LCR.peek(st, v);
    expect_eq("LCR restaurado por puerta trasera", v, ral.regs.LCR.get_reset());
    ral.regs.SCR.read(st, v, .parent(this));
    expect_eq("DLL en el espejo", ral.dl_regs.DLL.get_mirrored_value(), dl_wdata[7:0]);
    expect_eq("DLM en el espejo", ral.dl_regs.DLM.get_mirrored_value(), dl_wdata[15:8]);
    expect_eq("DLAB en el espejo", ral.regs.LCR.dlab.get_mirrored_value(), 0);
  endtask

  task check_reset_backdoor(uvm_reg rg, uvm_reg_data_t mask);
    uvm_status_e   st;
    uvm_reg_data_t v;
    rg.peek(st, v);
    `uvm_info("RAL", $sformatf("peek %s = 0x%0h (máscara 0x%0h, reset 0x%0h)",
                               rg.get_name(), v, mask, rg.get_reset()), 300)
    if (st != UVM_IS_OK)
      `uvm_error("RAL", $sformatf("peek de %s falló", rg.get_name()))
    else
      expect_eq({rg.get_name(), " reset por puerta trasera"}, v & mask, rg.get_reset() & mask);
  endtask

  function void expect_eq(string what, uvm_reg_data_t got, uvm_reg_data_t exp);
    if (got !== exp)
      `uvm_error("RAL", $sformatf("%s = 0x%0h, se esperaba 0x%0h", what, got, exp))
    else
      `uvm_info("RAL", $sformatf("%s = 0x%0h correcto", what, got), 100)
  endfunction

endclass : uart_ral_smoke_seq
