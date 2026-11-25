// Prueba de humo del agente Wishbone y de wishB_if, fuera de la regresión de uart_base_test.
// Ref: V-WB-01, V-WB-02, V-RST-01. Dueño: Eric.
class uart_wb_smoke_test extends uvm_test;
  `uvm_component_utils(uart_wb_smoke_test)

  // Si el monitor no publica, get() bloquea; el límite global evita una simulación sin fin.
  localparam time SMOKE_TIMEOUT = 100us;

  config_wishB cfg;
  wishB_agent  wishB_agt;
  uvm_tlm_analysis_fifo #(wishB_item) mon_fifo;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_top.set_timeout(SMOKE_TIMEOUT);

    cfg = config_wishB::type_id::create("cfg");
    cfg.parse_plusargs();
    // Se imprime antes de validar para que la traza quede en el log aunque check_knobs() corte.
    cfg.print_knobs();
    cfg.check_knobs();
    uvm_config_db#(config_wishB)::set(this, "wishB_agt*", "config_wishB", cfg);

    wishB_agt = wishB_agent::type_id::create("wishB_agt", this);
    mon_fifo  = new("mon_fifo", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    wishB_agt.wishB_ap.connect(mon_fifo.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    wishB_smoke_seq seq = wishB_smoke_seq::type_id::create("seq");
    wishB_item      seen;

    phase.raise_objection(this);
    `uvm_info("SMOKE", "Paso 1: lecturas de LCR, IIR y LSR, escritura y lectura de SCR", 200)
    seq.start(wishB_agt.sqr);

    `uvm_info("SMOKE", "Paso 2: valores leídos contra los valores esperados", 200)
    // Valores de reset leídos del RTL: uart_regs.v:477 (LCR), :410 y :860 (IIR), :666 y :677 (LSR).
    check_reg("LCR", seq.lcr, 8'h03);
    check_reg("IIR", seq.iir, 8'hC1);
    check_reg("LSR", seq.lsr, 8'h60);
    check_reg("SCR", seq.scr, seq.scr_wdata);

    `uvm_info("SMOKE", "Paso 3: cada transacción del monitor contra la del driver", 200)
    foreach (seq.done[i]) begin
      mon_fifo.get(seen);
      if (!seen.compare(seq.done[i]))
        `uvm_error("SMOKE", $sformatf("Monitor y driver no coinciden en la transacción %0d:\nmonitor:%s\ndriver:%s",
                                      i, seen.sprint(), seq.done[i].sprint()))
      else
        `uvm_info("SMOKE", $sformatf("Transacción %0d igual en monitor y driver", i), 100)
    end
    if (mon_fifo.used() != 0)
      `uvm_error("SMOKE", $sformatf("El monitor publicó %0d transacciones de más", mon_fifo.used()))

    phase.drop_objection(this);
  endtask

  function void check_reg(string name, bit [7:0] got, bit [7:0] exp);
    if (got !== exp)
      `uvm_error("SMOKE", $sformatf("%s = 0x%02h, se esperaba 0x%02h", name, got, exp))
    else
      `uvm_info("SMOKE", $sformatf("%s = 0x%02h correcto", name, got), 100)
  endfunction

  // Verbosidad: 0 veredicto (siempre se ve), 100 cada comprobación, 200 cada paso, 300 detalle de cada acceso.
  function void report_phase(uvm_phase phase);
    uvm_report_server srv = uvm_report_server::get_server();
    int unsigned      n_err = srv.get_severity_count(UVM_ERROR);
    if (n_err == 0)
      `uvm_info("SMOKE", "uart_wb_smoke_test PASÓ", 0)
    else
      `uvm_info("SMOKE", $sformatf("uart_wb_smoke_test FALLÓ con %0d UVM_ERROR", n_err), 0)
  endfunction

endclass : uart_wb_smoke_test
