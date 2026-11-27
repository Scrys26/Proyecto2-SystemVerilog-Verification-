
class config_mod extends uvm_object;
  `uvm_object_utils(config_mod)

  int unsigned modem_delay_max = 50;
  int unsigned modem_change_pct = 50;
  int unsigned mcr_loopback_pct = 20;
  int unsigned mcr_weights[4] = '{50, 50, 50, 50};
  int unsigned ier_weights[4] = '{50, 50, 50, 50};

  string knob_trace[$];

  function new(string name = "config_mod");
    super.new(name);
  endfunction

  // Solo uart_base_test llama este metodo.
  function void parse_plusargs();
    uvm_cmdline_processor clp;
    string s;
    bit found;

    clp = uvm_cmdline_processor::get_inst();
    knob_trace.delete();

    found = clp.get_arg_value(
      "+UART_MODEM_DELAY_MAX=", s) != 0;

    if (found)
      modem_delay_max = parse_unsigned(
        s, "UART_MODEM_DELAY_MAX");

    log_knob("UART_MODEM_DELAY_MAX",
      $sformatf("%0d", modem_delay_max), found);

    found = clp.get_arg_value(
      "+UART_MODEM_CHANGE_PCT=", s) != 0;

    if (found)
      modem_change_pct = parse_unsigned(
        s, "UART_MODEM_CHANGE_PCT");

    log_knob("UART_MODEM_CHANGE_PCT",
      $sformatf("%0d", modem_change_pct), found);

    found = clp.get_arg_value(
      "+UART_MCR_LOOPBACK_PCT=", s) != 0;

    if (found)
      mcr_loopback_pct = parse_unsigned(
        s, "UART_MCR_LOOPBACK_PCT");

    log_knob("UART_MCR_LOOPBACK_PCT",
      $sformatf("%0d", mcr_loopback_pct), found);

    found = clp.get_arg_value(
      "+UART_MCR_WEIGHTS=", s) != 0;

    if (found) begin
      if ($sscanf(s, "%d,%d,%d,%d",
                  mcr_weights[0], mcr_weights[1],
                  mcr_weights[2], mcr_weights[3]) != 4)
        `uvm_fatal("CFG_MOD",
          "UART_MCR_WEIGHTS necesita cuatro valores")
    end

    log_knob("UART_MCR_WEIGHTS",
      $sformatf("%p", mcr_weights), found);

    found = clp.get_arg_value(
      "+UART_IER_WEIGHTS=", s) != 0;

    if (found) begin
      if ($sscanf(s, "%d,%d,%d,%d",
                  ier_weights[0], ier_weights[1],
                  ier_weights[2], ier_weights[3]) != 4)
        `uvm_fatal("CFG_MOD",
          "UART_IER_WEIGHTS necesita cuatro valores")
    end

    log_knob("UART_IER_WEIGHTS",
      $sformatf("%p", ier_weights), found);

    check_knobs();
  endfunction

  function int unsigned parse_unsigned(
    string s, string name
  );
    int unsigned v;

    if (s.len() == 0 ||
        s[0] == 8'h2d ||
        $sscanf(s, "%d", v) != 1)
      `uvm_fatal("CFG_MOD",
        {name, " necesita un entero sin signo"})

    return v;
  endfunction

  function void log_knob(
    string name, string value, bit found
  );
    knob_trace.push_back(
      $sformatf("+%s=%s (%s)", name, value,
                found ? "plusarg" : "default"));
  endfunction

  function void check_knobs();

    if (modem_change_pct > 100)
      `uvm_fatal("CFG_MOD",
        "UART_MODEM_CHANGE_PCT fuera de 0..100")

    if (mcr_loopback_pct > 100)
      `uvm_fatal("CFG_MOD",
        "UART_MCR_LOOPBACK_PCT fuera de 0..100")

    foreach (mcr_weights[i]) begin
      if (mcr_weights[i] > 100)
        `uvm_fatal("CFG_MOD",
          "UART_MCR_WEIGHTS fuera de 0..100")
    end

    foreach (ier_weights[i]) begin
      if (ier_weights[i] > 100)
        `uvm_fatal("CFG_MOD",
          "UART_IER_WEIGHTS fuera de 0..100")
    end
  endfunction

  function void report_knobs();
    foreach (knob_trace[i])
      `uvm_info("KNOBS", knob_trace[i], UVM_LOW)
  endfunction

endclass : config_mod
