// Prueba de humo del agente serie: configura el UART, manda tráfico en las dos direcciones y deja que el modelo de referencia compare. Va fuera de la regresión de uart_base_test.

class serie_smoke_test extends uvm_test;
  `uvm_component_utils(serie_smoke_test)

  // Por si algo se queda esperando, la simulación no corre para siempre
  localparam time SMOKE_TIMEOUT = 20ms;

  config_wishB    wb_cfg;
  config_serie    ser_cfg;
  wishB_agent     wishB_agt;
  uart_ral_env    ral_env;
  serie_agent     serie_agt;
  uart_serie_sb   sb;

  virtual serie_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_top.set_timeout(SMOKE_TIMEOUT);

    if (!uvm_config_db#(virtual serie_if)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "serie_smoke_test no encontró la interfaz serie_if")

    wb_cfg = config_wishB::type_id::create("wb_cfg");
    wb_cfg.parse_plusargs();
    wb_cfg.print_knobs();
    wb_cfg.check_knobs();
    uvm_config_db#(config_wishB)::set(this, "wishB_agt*", "config_wishB", wb_cfg);

    // En la prueba de humo todo va sin errores, con ráfagas cortas para no llenar las FIFOs.
    // Se fija antes de leer los plusargs, así igual se pueden cambiar desde la terminal.
    ser_cfg = config_serie::type_id::create("ser_cfg");
    ser_cfg.ser_parity_err_pct   = 0;
    ser_cfg.ser_frame_err_pct    = 0;
    ser_cfg.ser_break_pct        = 0;
    ser_cfg.ser_glitch_pct       = 0;
    ser_cfg.ser_baud_out_pct     = 0;
    ser_cfg.ser_payload_max      = 8;
    ser_cfg.ser_payload_tail_pct = 0;
    ser_cfg.tx_payload_max       = 8;
    ser_cfg.tx_payload_tail_pct  = 0;
    ser_cfg.parse_plusargs();
    ser_cfg.report_knobs();

    // Divisor chico para que la prueba sea rápida, y sin break para que stx transmita
    if (!ser_cfg.randomize() with { dl inside {[1:4]}; tx_break == 0; })
      `uvm_fatal("CFG", "serie_smoke_test no pudo sortear la configuración de la línea")
    uvm_config_db#(config_serie)::set(this, "serie_agt*", "config_serie", ser_cfg);

    wishB_agt = wishB_agent::type_id::create("wishB_agt", this);
    ral_env   = uart_ral_env::type_id::create("ral_env", this);
    serie_agt = serie_agent::type_id::create("serie_agt", this);
    sb        = uart_serie_sb::type_id::create("sb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ral_env.connect_bus(wishB_agt.sqr, wishB_agt.wishB_ap);

    sb.adapter = ral_env.adapter;
    sb.regs    = ral_env.regs;
    wishB_agt.wishB_ap.connect(sb.wb_imp);
    serie_agt.serie_tx_ap.connect(sb.stx_imp);
    serie_agt.serie_rx_ap.connect(sb.srx_imp);
    serie_agt.serie_tx_pop_ap.connect(sb.pop_imp);
    serie_agt.serie_rx_push_ap.connect(sb.push_imp);
  endfunction

  task run_phase(uvm_phase phase);
    serie_tx_seq   tx_seq;
    serie_rx_seq   rx_seq;
    uvm_status_e   status;
    uvm_reg_data_t lsr;
    uvm_reg_data_t data;

    phase.raise_objection(this);

    // 1. Configurar el formato de la línea y el divisor
    `uvm_info("SER", $sformatf("Configurando LCR=0x%02h DL=%0d", ser_cfg.get_lcr(), ser_cfg.dl), UVM_LOW)
    ral_env.regs.LCR.write(status, ser_cfg.get_lcr());
    ral_env.write_dl(ser_cfg.dl, status);

    // 2. TX: escribir una ráfaga en THR y esperar a que todo salga por stx
    tx_seq      = serie_tx_seq::type_id::create("tx_seq");
    tx_seq.cfg  = ser_cfg;
    tx_seq.regs = ral_env.regs;
    tx_seq.start(wishB_agt.sqr);
    wait (sb.model.tx_fifo.size() == 0 && sb.model.tx_shift.size() == 0);

    // 3. RX: mandar una ráfaga por srx y dar tiempo a que el último carácter llegue a la FIFO
    rx_seq = serie_rx_seq::type_id::create("rx_seq");
    rx_seq.start(serie_agt.sqr);
    repeat (2 * 16 * ser_cfg.dl) @(vif.mon_cb);

    // 4. Leer RBR mientras el LSR diga que hay datos (DR, bit 0)
    ral_env.regs.LSR.read(status, lsr);
    while (lsr[0]) begin
      ral_env.regs.RBR.read(status, data);
      ral_env.regs.LSR.read(status, lsr);
    end

    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server srv = uvm_report_server::get_server();
    int unsigned      n_err = srv.get_severity_count(UVM_ERROR);
    if (n_err == 0)
      `uvm_info("SER", "serie_smoke_test PASÓ", UVM_NONE)
    else
      `uvm_info("SER", $sformatf("serie_smoke_test FALLÓ con %0d UVM_ERROR", n_err), UVM_NONE)
  endfunction

endclass : serie_smoke_test
