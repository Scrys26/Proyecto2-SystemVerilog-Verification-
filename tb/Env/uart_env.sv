class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_env_cfg cfg;

  wishB_agent wb_agt;
  serie_agent serie_agt;
  mod_agent modem_agt;
  int_monitor irq_mon;

  uart_ral_env ral;
  uart_modem_irq_sb modem_irq_sb;
  uart_serie_sb ser_sb;
  uart_serie_cov ser_cov;
  uart_virtual_sequencer v_sqr;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // El test crea esta configuracion antes de crear el ambiente.
    if (!uvm_config_db#(uart_env_cfg)::get(this, "", "uart_env_cfg", cfg))
      `uvm_fatal("UART_ENV", "Falta uart_env_cfg")

    if (cfg == null)
      `uvm_fatal("UART_ENV", "uart_env_cfg llego en null")

    cfg.check_cfg();

    // Cada agente recibe su configuracion.
    uvm_config_db#(config_wishB)::set(
      this, "wb_agt*", "config_wishB", cfg.wb_cfg);

    uvm_config_db#(config_serie)::set(
      this, "serie_agt*", "config_serie", cfg.ser_cfg);

    uvm_config_db#(config_mod)::set(
      this, "modem_agt*", "config_mod", cfg.modem_cfg);

    // Eric ya tiene el adaptador y predictor en este RAL.
    ral = uart_ral_env::type_id::create("ral", this);

    wb_agt = wishB_agent::type_id::create("wb_agt", this);
    serie_agt = serie_agent::type_id::create("serie_agt", this);
    modem_agt = mod_agent::type_id::create("modem_agt", this);
    irq_mon = int_monitor::type_id::create("irq_mon", this);

    modem_irq_sb = uart_modem_irq_sb::type_id::create(
      "modem_irq_sb", this);

    ser_sb = uart_serie_sb::type_id::create("ser_sb", this);
    ser_cov = uart_serie_cov::type_id::create("ser_cov", this);

    v_sqr = uart_virtual_sequencer::type_id::create(
      "v_sqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (wb_agt.sqr == null)
      `uvm_fatal("UART_ENV", "Wishbone debe estar activo para usar RAL")

    // Conectamos Wishbone al RAL de Eric.
    ral.connect_bus(wb_agt.sqr, wb_agt.wishB_ap);

    // La secuencia virtual usara estos handles.
    v_sqr.wb_sqr = wb_agt.sqr;
    v_sqr.ser_sqr = serie_agt.sqr;
    v_sqr.modem_sqr = modem_agt.pin_seqr;
    v_sqr.ral = ral;
    v_sqr.cfg = cfg;

    if (serie_agt.sqr == null)
      `uvm_warning("UART_ENV", "Serie esta pasivo; no podra transmitir desde v_sqr")

    if (modem_agt.pin_seqr == null)
      `uvm_warning("UART_ENV", "Modem esta pasivo; no podra generar cambios desde v_sqr")

    // Los monitores mandan sus transacciones al scoreboard.
    modem_agt.pin_mon.mod_ap.connect(modem_irq_sb.modem_in);
    wb_agt.wishB_ap.connect(modem_irq_sb.wb_in);
    irq_mon.int_ap.connect(modem_irq_sb.irq_in);

    // Scoreboard serie: usa el adaptador y el espejo del RAL para saber si un acceso es THR o RBR.
    ser_sb.adapter = ral.adapter;
    ser_sb.regs    = ral.regs;
    wb_agt.wishB_ap.connect(ser_sb.wb_imp);
    serie_agt.serie_tx_ap.connect(ser_sb.stx_imp);
    serie_agt.serie_rx_ap.connect(ser_sb.srx_imp);
    serie_agt.serie_tx_start_ap.connect(ser_sb.start_imp);

    // Cobertura serie: escucha a los mismos tres monitores que el scoreboard.
    ser_cov.adapter = ral.adapter;
    ser_cov.regs    = ral.regs;
    wb_agt.wishB_ap.connect(ser_cov.wb_imp);
    serie_agt.serie_tx_ap.connect(ser_cov.stx_imp);
    serie_agt.serie_rx_ap.connect(ser_cov.srx_imp);
  endfunction

endclass : uart_env