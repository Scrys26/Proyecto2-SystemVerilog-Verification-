
class uart_base_test extends uvm_test;
  `uvm_component_utils(uart_base_test)

  uart_env_cfg cfg;
  uart_env env;
  virtual wishB_if wb_vif;

  function new(string name = "uart_base_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = uart_env_cfg::type_id::create("cfg");

    // Solo el test llama los metodos que leen plusargs.
    cfg.parse_plusargs();
    cfg.wb_cfg.parse_plusargs();
    cfg.ser_cfg.parse_plusargs();
    cfg.modem_cfg.parse_plusargs();

    cfg.check_cfg();
    cfg.wb_cfg.check_knobs();
    cfg.ser_cfg.check_knobs();
    cfg.modem_cfg.check_knobs();

    check_uart_plusargs();

    // Mostramos los valores usados en la corrida.
    cfg.report_knobs();
    cfg.wb_cfg.print_knobs();
    cfg.ser_cfg.report_knobs();
    cfg.modem_cfg.report_knobs();

    uvm_config_db#(uart_env_cfg)::set(
      this, "env", "uart_env_cfg", cfg);

    uvm_config_db#(config_wishB)::set(
      this, "env.wb_agt*", "config_wishB", cfg.wb_cfg);

    uvm_config_db#(config_serie)::set(
      this, "env.serie_agt*", "config_serie", cfg.ser_cfg);

    uvm_config_db#(config_mod)::set(
      this, "env.modem_agt*", "config_mod", cfg.modem_cfg);

    env = uart_env::type_id::create("env", this);

    if (!uvm_config_db#(virtual wishB_if)::get(
          this, "", "vif", wb_vif))
      `uvm_fatal("BASE_TEST", "No se encontro wishB_if")
  endfunction

  // Revisamos que no haya plusargs mal escritos.
  function void check_uart_plusargs();
    uvm_cmdline_processor clp;
    string args[$];
    string name;
    bit known;
    bit has_equal;
    bit seen[string];

    clp = uvm_cmdline_processor::get_inst();
    clp.get_args(args);

    foreach (args[i]) begin
      if (args[i].len() < 6 ||
          args[i].substr(0, 5) != "+UART_")
        continue;

      name = "";
      has_equal = 0;

      for (int j = 1; j < args[i].len(); j++) begin
        if (args[i][j] == 8'h3d) begin
          has_equal = 1;
          break;
        end
        name = {name, args[i].substr(j, j)};
      end

      if (!has_equal)
        `uvm_error("PLUSARG",
          $sformatf("Falta =valor en %s", args[i]))

      if (seen.exists(name))
        `uvm_error("PLUSARG",
          $sformatf("Plusarg repetido: %s", name))

      seen[name] = 1;
      known = 1;

      case (name)
        "UART_CFG_TXN_MIN",
        "UART_CFG_TXN_MAX",
        "UART_LCR_WLS_WEIGHTS",
        "UART_LCR_STOP_WEIGHTS",
        "UART_LCR_PARITY_WEIGHTS",
        "UART_DL_ZERO_PCT",
        "UART_DL_MAX_FAST",
        "UART_DL_MAX",
        "UART_DL_TAIL_PCT",
        "UART_FCR_TL_WEIGHTS",
        "UART_FCR_CLEAR_PCT",
        "UART_IER_WEIGHTS",
        "UART_MCR_LOOPBACK_PCT",
        "UART_MCR_WEIGHTS",
        "UART_SW_MODE_WEIGHTS",
        "UART_TX_PAYLOAD_MAX",
        "UART_TX_PAYLOAD_TAIL_PCT",
        "UART_TX_BREAK_PCT",
        "UART_WB_DELAY_MAX",
        "UART_WB_DELAY_TAIL_PCT",
        "UART_WB_STB_DELAY_MIN",
        "UART_WB_STB_DELAY_MAX",
        "UART_WB_SEL_WEIGHTS",
        "UART_SER_PAYLOAD_MAX",
        "UART_SER_PAYLOAD_TAIL_PCT",
        "UART_SER_DELAY_MAX",
        "UART_SER_DELAY_TAIL_PCT",
        "UART_SER_PARITY_ERR_PCT",
        "UART_SER_FRAME_ERR_PCT",
        "UART_SER_BREAK_PCT",
        "UART_SER_GLITCH_PCT",
        "UART_SER_BAUD_DEV_MAX",
        "UART_SER_BAUD_OUT_PCT",
        "UART_MODEM_DELAY_MAX",
        "UART_MODEM_CHANGE_PCT",
        "UART_SW_POLL_MAX",
        "UART_SW_POLL_TAIL_PCT",
        "UART_SW_LSR_CHECK_MAX",
        "UART_SW_SERVICE_DELAY_MAX",
        "UART_SW_SERVICE_TAIL_PCT",
        "UART_SW_DRAIN_MAX",
        "UART_SW_IGNORE_PCT",
        "UART_REG_ACCESS_COUNT",
        "UART_REG_DLAB_PCT",
        "UART_REG_BITBASH_EN",
        "UART_REG_ACCESS_EN",
        "UART_RST_EN",
        "UART_RST_PCT": ;

        default: known = 0;
      endcase

      if (!known)
        `uvm_error("PLUSARG",
          $sformatf("Plusarg desconocido: %s", args[i]))
    end
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    // Por ahora probamos que el ambiente se construya.
    wait (wb_vif.rst === 1'b0);
    repeat (5) @(posedge wb_vif.clk);

    `uvm_info("BASE_TEST",
      "Ambiente creado. Falta uart_main_vseq para generar trafico.",
      UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass : uart_base_test
