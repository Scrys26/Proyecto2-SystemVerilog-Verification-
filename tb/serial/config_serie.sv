// Knobs y configuración aleatoria para la línea serie: formato de trama (LCR), divisor de baudrate, umbral de FIFO y tráfico.
typedef enum bit [2:0] {PAR_NONE, PAR_ODD, PAR_EVEN, PAR_STICK1, PAR_STICK0} serie_parity_e;

class config_serie extends uvm_object;
  `uvm_object_utils(config_serie)

  // Parámetros de línea que se programan en el DUT al arrancar la prueba
  rand bit [1:0]       wls;
  rand bit             stb;
  rand serie_parity_e  parity;
  rand bit [15:0]      dl;
  rand bit [1:0]       fcr_tl;
  rand bit             tx_break;

  // Knobs de formato de trama y divisor de reloj
  uint_q_t     lcr_wls_weights    = '{1, 1, 1, 1};
  uint_q_t     lcr_stop_weights   = '{1, 1};
  uint_q_t     lcr_parity_weights = '{1, 1, 1, 1, 1};
  int unsigned dl_zero_pct        = 1;
  int unsigned dl_max_fast        = 16;
  int unsigned dl_max             = 65535;
  int unsigned dl_tail_pct        = 2;
  uint_q_t     fcr_tl_weights     = '{1, 1, 1, 1};
  int unsigned fcr_clear_pct      = 10;

  // Knobs del tráfico TX (usados por la secuencia maestra sobre el bus Wishbone)
  int unsigned tx_payload_max      = 32;
  int unsigned tx_payload_tail_pct = 2;
  int unsigned tx_payload_abs_max  = 256;
  int unsigned tx_break_pct        = 3;

  // Knobs del tráfico RX y de la inyección de fallos en el agente serie
  int unsigned ser_payload_max      = 32;
  int unsigned ser_payload_tail_pct = 2;
  int unsigned ser_payload_abs_max  = 256;
  int unsigned ser_delay_max        = 20;
  int unsigned ser_delay_tail_pct   = 2;
  int unsigned ser_delay_abs_max    = 1000;
  int unsigned ser_parity_err_pct   = 5;
  int unsigned ser_frame_err_pct    = 5;
  int unsigned ser_break_pct        = 2;
  int unsigned ser_glitch_pct       = 3;
  int unsigned ser_baud_dev_max     = 10;
  int unsigned ser_baud_out_pct     = 20;

  // Registro de cada knob con su valor efectivo y origen (default vs. plusarg) para facilitar la reproducibilidad
  string knob_trace[$];

  constraint c_wls {
    wls dist { 0 := lcr_wls_weights[0], 1 := lcr_wls_weights[1],
               2 := lcr_wls_weights[2], 3 := lcr_wls_weights[3] };
  }

  constraint c_stop {
    stb dist { 0 := lcr_stop_weights[0], 1 := lcr_stop_weights[1] };
  }

  constraint c_parity {
    parity dist { PAR_NONE   := lcr_parity_weights[0], PAR_ODD    := lcr_parity_weights[1],
                  PAR_EVEN   := lcr_parity_weights[2], PAR_STICK1 := lcr_parity_weights[3],
                  PAR_STICK0 := lcr_parity_weights[4] };
  }

  // Valores altos de DL alargan demasiado la duración de cada bit y vuelven eternas las simulaciones;
  //por eso priorizamos el rango rápido [1 : dl_max_fast], dejando el resto y DL=0 con baja probabilidad.
  constraint c_dl {
    dl dist { 0                          :/ dl_zero_pct,
              [1 : dl_max_fast]          :/ 100 - dl_zero_pct - dl_tail_pct,
              [dl_max_fast + 1 : dl_max] :/ dl_tail_pct };
  }

  constraint c_fcr {
    fcr_tl dist { 0 := fcr_tl_weights[0], 1 := fcr_tl_weights[1],
                  2 := fcr_tl_weights[2], 3 := fcr_tl_weights[3] };
  }

  constraint c_tx_break {
    tx_break dist { 1 := tx_break_pct, 0 := 100 - tx_break_pct };
  }

  function new(string name = "config_serie");
    super.new(name);
  endfunction

  // Construye el byte del registro LCR a partir de los campos aleatorizados (mantiene DLAB = 0)
  function bit [7:0] get_lcr();
    bit pe, ep, sp;
    case (parity)
      PAR_NONE:   {sp, ep, pe} = 3'b000;
      PAR_ODD:    {sp, ep, pe} = 3'b001;
      PAR_EVEN:   {sp, ep, pe} = 3'b011;
      PAR_STICK1: {sp, ep, pe} = 3'b101;
      PAR_STICK0: {sp, ep, pe} = 3'b111;
    endcase
    return {1'b0, tx_break, sp, ep, pe, stb, wls};
  endfunction

  // Punto único de lectura de plusargs para este bloque; el test lo invoca antes de randomize()
  function void parse_plusargs();
    knob_trace.delete();
    lcr_wls_weights      = read_weights("UART_LCR_WLS_WEIGHTS",     lcr_wls_weights);
    lcr_stop_weights     = read_weights("UART_LCR_STOP_WEIGHTS",    lcr_stop_weights);
    lcr_parity_weights   = read_weights("UART_LCR_PARITY_WEIGHTS",  lcr_parity_weights);
    dl_zero_pct          = read_int("UART_DL_ZERO_PCT",             dl_zero_pct);
    dl_max_fast          = read_int("UART_DL_MAX_FAST",             dl_max_fast);
    dl_max               = read_int("UART_DL_MAX",                  dl_max);
    dl_tail_pct          = read_int("UART_DL_TAIL_PCT",             dl_tail_pct);
    fcr_tl_weights       = read_weights("UART_FCR_TL_WEIGHTS",      fcr_tl_weights);
    fcr_clear_pct        = read_int("UART_FCR_CLEAR_PCT",           fcr_clear_pct);
    tx_payload_max       = read_int("UART_TX_PAYLOAD_MAX",          tx_payload_max);
    tx_payload_tail_pct  = read_int("UART_TX_PAYLOAD_TAIL_PCT",     tx_payload_tail_pct);
    tx_break_pct         = read_int("UART_TX_BREAK_PCT",            tx_break_pct);
    ser_payload_max      = read_int("UART_SER_PAYLOAD_MAX",         ser_payload_max);
    ser_payload_tail_pct = read_int("UART_SER_PAYLOAD_TAIL_PCT",    ser_payload_tail_pct);
    ser_delay_max        = read_int("UART_SER_DELAY_MAX",           ser_delay_max);
    ser_delay_tail_pct   = read_int("UART_SER_DELAY_TAIL_PCT",      ser_delay_tail_pct);
    ser_parity_err_pct   = read_int("UART_SER_PARITY_ERR_PCT",      ser_parity_err_pct);
    ser_frame_err_pct    = read_int("UART_SER_FRAME_ERR_PCT",       ser_frame_err_pct);
    ser_break_pct        = read_int("UART_SER_BREAK_PCT",           ser_break_pct);
    ser_glitch_pct       = read_int("UART_SER_GLITCH_PCT",          ser_glitch_pct);
    ser_baud_dev_max     = read_int("UART_SER_BAUD_DEV_MAX",        ser_baud_dev_max);
    ser_baud_out_pct     = read_int("UART_SER_BAUD_OUT_PCT",        ser_baud_out_pct);
  endfunction

  // Valida que los knobs no generen rangos vacíos ni restricciones contradictorias, evitando fallos silenciosos o 
  // mensajes crípticos del solver durante randomize().
  function void check_knobs();
    check(lcr_wls_weights.size() == 4,    "UART_LCR_WLS_WEIGHTS necesita 4 pesos");
    check(lcr_stop_weights.size() == 2,   "UART_LCR_STOP_WEIGHTS necesita 2 pesos");
    check(lcr_parity_weights.size() == 5, "UART_LCR_PARITY_WEIGHTS necesita 5 pesos");
    check(fcr_tl_weights.size() == 4,     "UART_FCR_TL_WEIGHTS necesita 4 pesos");
    check(lcr_wls_weights.sum() > 0 && lcr_stop_weights.sum() > 0 &&
          lcr_parity_weights.sum() > 0 && fcr_tl_weights.sum() > 0,
          "una lista de pesos no puede ser toda 0");

    check(dl_max <= 65535,                   "UART_DL_MAX no cabe en 16 bits");
    check(dl_max_fast >= 1 && dl_max_fast <= dl_max, "UART_DL_MAX_FAST tiene que estar entre 1 y UART_DL_MAX");
    check(dl_zero_pct + dl_tail_pct <= 100,  "UART_DL_ZERO_PCT + UART_DL_TAIL_PCT pasa de 100");
    check(dl_tail_pct == 0 || dl_max_fast < dl_max, "la cola de DL está vacía: UART_DL_MAX_FAST igual a UART_DL_MAX");

    check(ser_parity_err_pct + ser_frame_err_pct + ser_break_pct <= 100,
          "la suma de UART_SER_PARITY_ERR_PCT, FRAME_ERR_PCT y BREAK_PCT pasa de 100");
    check(ser_glitch_pct <= 100 && ser_baud_out_pct <= 100 && fcr_clear_pct <= 100 && tx_break_pct <= 100,
          "un porcentaje pasa de 100");
    check(ser_baud_out_pct == 0 || ser_baud_dev_max > UART_BAUD_TOL_PCT,
          "hay tramas fuera de tolerancia pero UART_SER_BAUD_DEV_MAX no pasa la tolerancia");

    check_tail("UART_SER_DELAY",   ser_delay_max,   ser_delay_tail_pct,   ser_delay_abs_max);
    check_tail("UART_SER_PAYLOAD", ser_payload_max, ser_payload_tail_pct, ser_payload_abs_max);
    check_tail("UART_TX_PAYLOAD",  tx_payload_max,  tx_payload_tail_pct,  tx_payload_abs_max);
    check(ser_payload_max >= 1 && tx_payload_max >= 1, "una ráfaga tiene que tener al menos 1 carácter");
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
    if (!ok) `uvm_fatal("CFG", {"config_serie: ", msg})
  endfunction

  // Si hay probabilidad de cola (> 0%), debe existir al menos un valor válido por encima del rango rápido
  local function void check_tail(string name, int unsigned max_fast, int unsigned tail_pct, int unsigned abs_max);
    check(tail_pct <= 100, {name, "_TAIL_PCT pasa de 100"});
    check(tail_pct == 0 || max_fast < abs_max, {"la cola de ", name, " está vacía: el máximo rápido llega al tope"});
  endfunction

endclass : config_serie