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
  // Mínimo 1: con stb sostenido entre transferencias el DUT da ack sin ejecutar el acceso
  // (uart_wb.v:208, 224-225). Con +UART_WB_STB_DELAY_MIN=0 se reproduce ese caso.
  int unsigned wb_stb_delay_min  = 1;
  int unsigned wb_stb_delay_max  = 3;

  // Orden byte de la dirección N[1:0] = 0, 1, 2, 3 (sel = 1000, 0100, 0010, 0001 del rtl
  // uart_wb.v:293-298).
  int unsigned wb_sel_weights[4] = '{1, 1, 1, 1};

  string knob_trace[$];

  function new(string name = "config_wishB");
    super.new(name);
  endfunction

  // Solo la llama uart_base_test (E2).
  function void parse_plusargs();
    knob_trace.delete();
    wb_delay_max      = read_int("UART_WB_DELAY_MAX",          wb_delay_max);
    wb_delay_tail_pct = read_int("UART_WB_DELAY_TAIL_PCT",     wb_delay_tail_pct);
    wb_stb_delay_min  = read_int("UART_WB_STB_DELAY_MIN",      wb_stb_delay_min);
    wb_stb_delay_max  = read_int("UART_WB_STB_DELAY_MAX",      wb_stb_delay_max);
    read_weights4("UART_WB_SEL_WEIGHTS", wb_sel_weights);
  endfunction

  function void check_knobs();
    check(wb_sel_weights.sum() > 0,    "UART_WB_SEL_WEIGHTS no puede ser toda 0");
    check(wb_delay_tail_pct <= 100,    "UART_WB_DELAY_TAIL_PCT pasa de 100");
    check(wb_stb_delay_min <= wb_stb_delay_max, "UART_WB_STB_DELAY_MIN es mayor que UART_WB_STB_DELAY_MAX");
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

  local function void read_weights4(string name, ref int unsigned w[4]);
    uvm_cmdline_processor clp = uvm_cmdline_processor::get_inst();
    string s;
    if (clp.get_arg_value({"+", name, "="}, s)) begin
      // Se exigen los 4 pesos: con menos, $sscanf dejaría valores por defecto sin avisar.
      check($sscanf(s, "%d,%d,%d,%d", w[0], w[1], w[2], w[3]) == 4,
            {name, " necesita 4 pesos separados por comas"});
      knob_trace.push_back($sformatf("+%s = %p (plusarg)", name, w));
    end
    else
      knob_trace.push_back($sformatf("+%s = %p (default)", name, w));
  endfunction

  local function void check(bit ok, string msg);
    if (!ok) `uvm_fatal("CFG", {"config_wishB: ", msg})
  endfunction

endclass : config_wishB
