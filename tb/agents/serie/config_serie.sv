// Configuración del agente serie, perillas que ajustan el trafico por srx y errores inyectados, además qué tan seguido se mandan tramas con errores.

typedef enum bit [2:0] {PAR_NONE, PAR_ODD, PAR_EVEN, PAR_STICK1, PAR_STICK0} serie_parity_e;

class config_serie extends uvm_object;
  `uvm_object_utils(config_serie)

  // Variables que se sortean en cada corrida y que se programa al iniciar el UART
  rand bit [1:0]       char_length;
  rand bit             stop_bit;
  rand serie_parity_e  parity;
  rand bit [15:0]      dl; // De 1 a 65535, controla el baudrate. Donde 1 es la más rápida
  rand bit [1:0]       fifo_trigger; // 0: 1 byte, 1: 4 bytes, 2: 8 bytes, 3: 14 bytes
  rand bit             tx_break;

  // Pesos y rangos con que se sortea las variables anteriores.
  int unsigned lcr_wls_weights[4]    = '{1, 1, 1, 1};
  int unsigned lcr_stop_weights[2]   = '{1, 1};
  int unsigned lcr_parity_weights[5] = '{1, 1, 1, 1, 1};
  int unsigned fcr_tl_weights[4]     = '{1, 1, 1, 1};
  int unsigned fcr_clear_pct         = 10; //% vaciar fifos

  // DL: Rango del divisor (controla el baudrate), casi siempre peuqueño a propósito
  int unsigned dl_zero_pct           = 1;
  int unsigned dl_max_fast           = 16;
  int unsigned dl_max                = 65535;
  int unsigned dl_tail_pct           = 2;

  // Cuántos bytes se escriben seguidos para que el UART los transmita
  int unsigned tx_payload_max        = 32;
  int unsigned tx_payload_tail_pct   = 2;
  int unsigned tx_payload_abs_max    = 256;
  int unsigned tx_break_pct          = 3; 

  // Cuántos caracteres seguidos le mandamos al UART por srx
  int unsigned ser_payload_max       = 32;
  int unsigned ser_payload_tail_pct  = 2; 
  int unsigned ser_payload_abs_max   = 256;

  // Cuánto esperamos entre un carácter y el siguiente, medido en bits
  int unsigned ser_delay_max         = 20;
  int unsigned ser_delay_tail_pct    = 2; 
  int unsigned ser_delay_abs_max     = 1000;

  // De cada 100 caracteres, cuántos van con cada tipo de error
  int unsigned ser_parity_err_pct    = 5;
  int unsigned ser_frame_err_pct     = 5;
  int unsigned ser_break_pct         = 2;
  int unsigned ser_glitch_pct        = 3;

  // Qué tanto nos salimos de la velocidad correcta y qué tanto de los caracteres van a una velocidad que el dut no aguanta
  int unsigned ser_baud_dev_max      = 10; // % de la velocidad nominal
  int unsigned ser_baud_out_pct      = 20; // % de los caracteres van a una velocidad que el dut no aguanta

  // Lista de cada perilla con su valor y si vino por defecto o por plusarg
  string knob_log[$];

/* constraint NOMBRE {
  VARIABLE dist { VALOR := PESO, VALOR := PESO };
} 
*/
// Cada restricción reparte las opciones según los pesos de arriba, permiten controlar el azar
  constraint c_char_length {
    char_length dist { 0 := lcr_wls_weights[0], 1 := lcr_wls_weights[1],
                       2 := lcr_wls_weights[2], 3 := lcr_wls_weights[3] };
  }

  constraint c_stop_bit {
    stop_bit dist { 0 := lcr_stop_weights[0], 1 := lcr_stop_weights[1] };
  }

  constraint c_parity {
    parity dist { PAR_NONE   := lcr_parity_weights[0], PAR_ODD    := lcr_parity_weights[1],
                  PAR_EVEN   := lcr_parity_weights[2], PAR_STICK1 := lcr_parity_weights[3],
                  PAR_STICK0 := lcr_parity_weights[4] };
  }

  constraint c_fifo_trigger {
    fifo_trigger dist { 0 := fcr_tl_weights[0], 1 := fcr_tl_weights[1],
                        2 := fcr_tl_weights[2], 3 := fcr_tl_weights[3] };
  }

  // El divisor tiene tres zonas: cero, el rango rápido y la cola de valores grandes
  constraint c_dl {
    dl dist { 0                          :/ dl_zero_pct,
              [1 : dl_max_fast]          :/ 100 - dl_zero_pct - dl_tail_pct,
              [dl_max_fast + 1 : dl_max] :/ dl_tail_pct };
  }

  constraint c_tx_break {
    tx_break dist { 1 := tx_break_pct, 0 := 100 - tx_break_pct };
  }

  function new(string name = "config_serie");
    super.new(name);
  endfunction

    // Arma el valor que se escribe en el registro LCR con lo que salió en el sorteo
  function bit [7:0] get_lcr();
    bit [7:0] lcr;
    lcr      = 8'h00;
    lcr[1:0] = char_length;
    lcr[2]   = stop_bit;
    case (parity)
      PAR_NONE:   lcr[5:3] = 3'b000;
      PAR_ODD:    lcr[5:3] = 3'b001;
      PAR_EVEN:   lcr[5:3] = 3'b011;
      PAR_STICK1: lcr[5:3] = 3'b101;
      PAR_STICK0: lcr[5:3] = 3'b111;
    endcase
    lcr[6]   = tx_break;
    return lcr;
  endfunction

  // Métodos que permiten que un plusarg llegue hasta un knob

  // Busca un plusarg en la línea de comando. Devuelve 1 si lo encontró y deja su texto en value.
  function bit find_arg(string name, output string value);
    uvm_cmdline_processor clp = uvm_cmdline_processor::get_inst();
    return clp.get_arg_value({"+", name, "="}, value) != 0;
  endfunction

  function void log_knob(string name, string value, bit found);
    knob_log.push_back($sformatf("+%s = %s (%s)", name, value, found ? "plusarg" : "defecto"));
  endfunction

  // Lee una perilla numérica, si el plusarg viene, pisa el valor por defecto
  function void read_int(string name, ref int unsigned knob);
    string s;
    bit    found;
    found = find_arg(name, s);
    if (found) knob = s.atoi();
    log_knob(name, $sformatf("%0d", knob), found);
  endfunction

  // Único lugar del agente serie donde se lee la línea de comando
  function void parse_plusargs();
    string s;
    bit    found;
    knob_log.delete();

    found = find_arg("UART_LCR_WLS_WEIGHTS", s);
    if (found) void'($sscanf(s, "%d,%d,%d,%d", lcr_wls_weights[0], lcr_wls_weights[1],
                                               lcr_wls_weights[2], lcr_wls_weights[3]));
    log_knob("UART_LCR_WLS_WEIGHTS", $sformatf("%p", lcr_wls_weights), found);

    found = find_arg("UART_LCR_STOP_WEIGHTS", s);
    if (found) void'($sscanf(s, "%d,%d", lcr_stop_weights[0], lcr_stop_weights[1]));
    log_knob("UART_LCR_STOP_WEIGHTS", $sformatf("%p", lcr_stop_weights), found);

    found = find_arg("UART_LCR_PARITY_WEIGHTS", s);
    if (found) void'($sscanf(s, "%d,%d,%d,%d,%d", lcr_parity_weights[0], lcr_parity_weights[1],
                             lcr_parity_weights[2], lcr_parity_weights[3], lcr_parity_weights[4]));
    log_knob("UART_LCR_PARITY_WEIGHTS", $sformatf("%p", lcr_parity_weights), found);

    found = find_arg("UART_FCR_TL_WEIGHTS", s);
    if (found) void'($sscanf(s, "%d,%d,%d,%d", fcr_tl_weights[0], fcr_tl_weights[1],
                                               fcr_tl_weights[2], fcr_tl_weights[3]));
    log_knob("UART_FCR_TL_WEIGHTS", $sformatf("%p", fcr_tl_weights), found);

    read_int("UART_FCR_CLEAR_PCT",        fcr_clear_pct);
    read_int("UART_DL_ZERO_PCT",          dl_zero_pct);
    read_int("UART_DL_MAX_FAST",          dl_max_fast);
    read_int("UART_DL_MAX",               dl_max);
    read_int("UART_DL_TAIL_PCT",          dl_tail_pct);
    read_int("UART_TX_PAYLOAD_MAX",       tx_payload_max);
    read_int("UART_TX_PAYLOAD_TAIL_PCT",  tx_payload_tail_pct);
    read_int("UART_TX_BREAK_PCT",         tx_break_pct);
    read_int("UART_SER_PAYLOAD_MAX",      ser_payload_max);
    read_int("UART_SER_PAYLOAD_TAIL_PCT", ser_payload_tail_pct);
    read_int("UART_SER_DELAY_MAX",        ser_delay_max);
    read_int("UART_SER_DELAY_TAIL_PCT",   ser_delay_tail_pct);
    read_int("UART_SER_PARITY_ERR_PCT",   ser_parity_err_pct);
    read_int("UART_SER_FRAME_ERR_PCT",    ser_frame_err_pct);
    read_int("UART_SER_BREAK_PCT",        ser_break_pct);
    read_int("UART_SER_GLITCH_PCT",       ser_glitch_pct);
    read_int("UART_SER_BAUD_DEV_MAX",     ser_baud_dev_max);
    read_int("UART_SER_BAUD_OUT_PCT",     ser_baud_out_pct);

    check_knobs();
  endfunction

  // Corta la corrida si una perilla quedó con un valor que haría fallar el sorteo
  function void check_knobs();
    if (lcr_wls_weights.sum() == 0 || lcr_stop_weights.sum() == 0 ||
        lcr_parity_weights.sum() == 0 || fcr_tl_weights.sum() == 0)
      `uvm_fatal("CFG", "config_serie: una lista de pesos no puede ser toda 0")

    if (dl_zero_pct + dl_tail_pct > 100)
    `uvm_fatal("CFG", "config_serie: UART_DL_ZERO_PCT + UART_DL_TAIL_PCT pasa de 100")
    if (dl_max_fast < 1 || dl_max_fast >= dl_max || dl_max > 65535)
      `uvm_fatal("CFG", "config_serie: se necesita 1 <= UART_DL_MAX_FAST < UART_DL_MAX <= 65535")

    if (ser_parity_err_pct + ser_frame_err_pct + ser_break_pct > 100)
      `uvm_fatal("CFG", "config_serie: los porcentajes de error de UART_SER_* suman más de 100")
    if (tx_break_pct > 100 || fcr_clear_pct > 100 || ser_glitch_pct > 100 || ser_baud_out_pct > 100 ||
        tx_payload_tail_pct > 100 || ser_payload_tail_pct > 100 || ser_delay_tail_pct > 100)
      `uvm_fatal("CFG", "config_serie: hay un porcentaje mayor que 100")

    if (tx_payload_max < 1 || tx_payload_max >= tx_payload_abs_max)
      `uvm_fatal("CFG", "config_serie: UART_TX_PAYLOAD_MAX tiene que estar entre 1 y el tope de la cola")
    if (ser_payload_max < 1 || ser_payload_max >= ser_payload_abs_max)
      `uvm_fatal("CFG", "config_serie: UART_SER_PAYLOAD_MAX tiene que estar entre 1 y el tope de la cola")
    if (ser_delay_max >= ser_delay_abs_max)
      `uvm_fatal("CFG", "config_serie: UART_SER_DELAY_MAX tiene que ser menor que el tope de la cola")
  endfunction

  function void report_knobs();
    foreach (knob_log[i])
      `uvm_info("KNOBS", knob_log[i], UVM_LOW)
  endfunction

endclass : config_serie