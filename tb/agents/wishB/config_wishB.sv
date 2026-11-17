// Knobs del agente Wishbone: retardos entre transacciones, retardo de stb y selección de byte.
// Ref: V-WB-01, V-WB-02, CE-08. Dueño: Eric.
class config_wishB extends uvm_object;
  `uvm_object_utils(config_wishB)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  // Lo podems definir en el tb_top para que el adaptador sepa 
  // el ancho sin depender del define variante de 8 bits

  int unsigned bus_width = `UART_DATA_WIDTH;

  int unsigned wb_delay_max      = 20;
  int unsigned wb_delay_tail_pct = 2;

  // Tope de la cola; no es plusarg porque CE-08 solo necesita cambiar la probabilidad, no el tope.
  int unsigned wb_delay_abs_max  = 1000;
  int unsigned wb_stb_delay_max  = 3;

  // Orden byte de la dirección N[1:0] = 0, 1, 2, 3 (sel = 1000, 0100, 0010, 0001 del rtl
  // uart_wb.v:293-298).
  uint_q_t     wb_sel_weights    = '{1, 1, 1, 1};

  string knob_trace[$];

  function new(string name = "config_wishB");
    super.new(name);
  endfunction

<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
  // Solo la llama uart_base_test .
=======
  // Solo la llama uart_base_test (E2).
>>>>>>> bb973a4 (Agrega config_wishB y el knob UART_WB_STB_DELAY_MAX)
=======
  // Solo la llama uart_base_test .
>>>>>>> 1b70ae5 (Add wishB_driver and wishB_sequencer classes for Wishbone protocol handling)
=======
  // Solo la llama uart_base_test (E2).
>>>>>>> 368c4c43f048b6d27090a6cf85bdb0209ec4dce8
  function void parse_plusargs();
    knob_trace.delete();
    wb_delay_max      = read_int("UART_WB_DELAY_MAX",          wb_delay_max);
    wb_delay_tail_pct = read_int("UART_WB_DELAY_TAIL_PCT",     wb_delay_tail_pct);
    wb_stb_delay_max  = read_int("UART_WB_STB_DELAY_MAX",      wb_stb_delay_max);
    wb_sel_weights    = read_weights("UART_WB_SEL_WEIGHTS",    wb_sel_weights);
  endfunction

  function void check_knobs();
    check(wb_sel_weights.size() == 4,  "UART_WB_SEL_WEIGHTS necesita 4 pesos");
    check(wb_sel_weights.sum() > 0,    "UART_WB_SEL_WEIGHTS no puede ser toda 0");
    check(wb_delay_tail_pct <= 100,    "UART_WB_DELAY_TAIL_PCT pasa de 100");
    check(wb_delay_max <= wb_delay_abs_max, "UART_WB_DELAY_MAX pasa del tope de la cola");
    check(wb_delay_tail_pct == 0 || wb_delay_max < wb_delay_abs_max,
          "la cola de UART_WB_DELAY está vacía: el máximo rápido llega al tope");
  endfunction

  function void print_knobs();
    foreach (knob_trace[i])
      `uvm_info("KNOBS", knob_trace[i], UVM_LOW)
  endfunction

  local function int unsigned read_int(string name, int unsigned def);
    uvm_cmdline_processor clp = uvm_cmdline_processor::get_inst();
    string s;
    if (clp.get_arg_value({"+", name, "="}, s)) begin
      knob_trace.push_back($sformatf("+%s = %0d (plusarg)", name, s.atoi()));
      return s.atoi();
    end
    knob_trace.push_back($sformatf("+%s = %0d (default)", name, def));
    return def;
  endfunction

  local function uint_q_t read_weights(string name, uint_q_t def);
    uvm_cmdline_processor clp = uvm_cmdline_processor::get_inst();
    string s;
    if (clp.get_arg_value({"+", name, "="}, s)) begin
      knob_trace.push_back($sformatf("+%s = %s (plusarg)", name, s));
      return config_utils::csv_to_ints(s);
    end
    knob_trace.push_back($sformatf("+%s = %p (default)", name, def));
    return def;
  endfunction

  local function void check(bit ok, string msg);
    if (!ok) `uvm_fatal("CFG", {"config_wishB: ", msg})
  endfunction

endclass : config_wishB
