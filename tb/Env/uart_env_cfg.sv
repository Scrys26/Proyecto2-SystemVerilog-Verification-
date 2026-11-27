
class uart_env_cfg extends uvm_object;
  `uvm_object_utils(uart_env_cfg)

  config_wishB wb_cfg;
  config_serie ser_cfg;
  config_mod modem_cfg;

  int unsigned modem_steps = 20;

  int unsigned cfg_txn_min = 20;
  int unsigned cfg_txn_max = 200;

  int unsigned sw_mode_weights[3] = '{1, 1, 1};
  int unsigned sw_poll_max = 100;
  int unsigned sw_poll_tail_pct = 2;
  int unsigned sw_lsr_check_max = 4;
  int unsigned sw_service_delay_max = 8;
  int unsigned sw_service_tail_pct = 2;
  int unsigned sw_drain_max = 16;
  int unsigned sw_ignore_pct = 5;

  int unsigned reg_access_count = 4;
  int unsigned reg_dlab_pct = 20;
  int unsigned reg_bitbash_en = 0;
  int unsigned reg_access_en = 0;

  int unsigned rst_en = 0;
  int unsigned rst_pct = 10;

  string knob_trace[$];

  function new(string name = "uart_env_cfg");
    super.new(name);

    wb_cfg = config_wishB::type_id::create("wb_cfg");
    ser_cfg = config_serie::type_id::create("ser_cfg");
    modem_cfg = config_mod::type_id::create("modem_cfg");
  endfunction

  // Leemos los parametros del ambiente y de los agentes.
  function void parse_plusargs();
    uvm_cmdline_processor clp;
    string s;
    bit found;

    knob_trace.delete();

    read_int("UART_CFG_TXN_MIN", cfg_txn_min);
    read_int("UART_CFG_TXN_MAX", cfg_txn_max);

    clp = uvm_cmdline_processor::get_inst();

    found = clp.get_arg_value(
      "+UART_SW_MODE_WEIGHTS=", s) != 0;

    if (found) begin
      if ($sscanf(s, "%d,%d,%d",
                  sw_mode_weights[0],
                  sw_mode_weights[1],
                  sw_mode_weights[2]) != 3)
        `uvm_fatal("ENV_CFG",
          "UART_SW_MODE_WEIGHTS necesita tres valores")
    end

    log_knob("UART_SW_MODE_WEIGHTS",
             $sformatf("%p", sw_mode_weights), found);

    read_int("UART_SW_POLL_MAX", sw_poll_max);
    read_int("UART_SW_POLL_TAIL_PCT", sw_poll_tail_pct);
    read_int("UART_SW_LSR_CHECK_MAX", sw_lsr_check_max);
    read_int("UART_SW_SERVICE_DELAY_MAX", sw_service_delay_max);
    read_int("UART_SW_SERVICE_TAIL_PCT", sw_service_tail_pct);
    read_int("UART_SW_DRAIN_MAX", sw_drain_max);
    read_int("UART_SW_IGNORE_PCT", sw_ignore_pct);

    read_int("UART_REG_ACCESS_COUNT", reg_access_count);
    read_int("UART_REG_DLAB_PCT", reg_dlab_pct);
    read_int("UART_REG_BITBASH_EN", reg_bitbash_en);
    read_int("UART_REG_ACCESS_EN", reg_access_en);

    read_int("UART_RST_EN", rst_en);
    read_int("UART_RST_PCT", rst_pct);

    // Cada agente lee sus propios knobs.
    wb_cfg.parse_plusargs();
    ser_cfg.parse_plusargs();
    modem_cfg.parse_plusargs();

    check_cfg();
  endfunction

  function void read_int(string name, ref int unsigned field);
    uvm_cmdline_processor clp;
    string s;
    bit found;
    int unsigned value;

    clp = uvm_cmdline_processor::get_inst();
    found = clp.get_arg_value({"+", name, "="}, s) != 0;

    if (found) begin
      if (s.len() == 0 ||
          s[0] == 8'h2d ||
          $sscanf(s, "%d", value) != 1)
        `uvm_fatal("ENV_CFG",
          {name, " necesita un entero sin signo"})

      field = value;
    end

    log_knob(name, $sformatf("%0d", field), found);
  endfunction

  function void log_knob(
    string name,
    string value,
    bit found
  );
    knob_trace.push_back(
      $sformatf("+%s=%s (%s)",
        name, value, found ? "plusarg" : "default"));
  endfunction

  function void check_cfg();

    if (wb_cfg == null ||
        ser_cfg == null ||
        modem_cfg == null)
      `uvm_fatal("ENV_CFG",
        "Falta una configuracion de agente")

    if (cfg_txn_min < 1 || cfg_txn_max < cfg_txn_min)
      `uvm_fatal("ENV_CFG", "UART_CFG_TXN_MIN/MAX invalidos")

    if (sw_mode_weights.sum() == 0)
      `uvm_fatal("ENV_CFG",
        "UART_SW_MODE_WEIGHTS no puede ser toda 0")

    if (sw_poll_tail_pct > 100 ||
        sw_service_tail_pct > 100 ||
        sw_ignore_pct > 100 ||
        reg_dlab_pct > 100 ||
        rst_pct > 100)
      `uvm_fatal("ENV_CFG", "Porcentaje fuera de 0..100")

    if (sw_poll_max > 10000 ||
        sw_service_delay_max > 100)
      `uvm_fatal("ENV_CFG",
        "Retardos fuera del tope de su cola")

    if (sw_drain_max < 1 || sw_drain_max > 16)
      `uvm_fatal("ENV_CFG",
        "UART_SW_DRAIN_MAX fuera de 1..16")

    if (reg_bitbash_en > 1 ||
        reg_access_en > 1 ||
        rst_en > 1)
      `uvm_fatal("ENV_CFG",
        "Un habilitador debe valer 0 o 1")
  endfunction

  function void report_knobs();
    foreach (knob_trace[i])
      `uvm_info("KNOBS", knob_trace[i], UVM_LOW)

    `uvm_info("KNOBS",
      $sformatf("modem_steps=%0d (default interno)", modem_steps),
      UVM_LOW)
  endfunction

endclass : uart_env_cfg
