class uart_int_model extends uvm_object;
  `uvm_object_utils(uart_int_model)

  // Interrupt Enable Register: [3] modem, [2] RLS, [1] THRE, [0] RX/timeout.
  local bit [3:0] ier;

  // Fuentes predichas por los modelos independientes 
  local bit [7:0]     lsr_expected;
  local int unsigned  rx_count_expected;
  local int unsigned  rx_trigger_expected;
  local bit           timeout_expected;       // counter_t == 0, calculado afuera
  local bit [3:0]     msr_delta_expected;

  // Equivalentes abstractos de los cinco registros *_int_pnd del RTL.
  local bit rls_pending;
  local bit rda_pending;
  local bit timeout_pending;
  local bit thre_pending;
  local bit modem_pending;

  // Equivalentes de *_int_d: deteccion de flancos ascendentes.
  local bit rls_delayed;
  local bit rda_delayed;
  local bit timeout_delayed;
  local bit thre_delayed;
  local bit modem_delayed;

  // Valores registrados de las salidas del bloque de interrupciones.
  local bit [3:0] iir_registered;
  local bit       irq_registered;

  function new(string name = "uart_int_model");
    super.new(name);
    reset_model();
  endfunction

  function void reset_model();
    ier                 = 4'b0000;
    lsr_expected        = 8'h60;  // THRE y TEMT luego del reset.
    rx_count_expected   = 0;
    rx_trigger_expected = 14;     // FCR[7:6] = 2'b11 al reset de este RTL.
    timeout_expected    = 0;
    msr_delta_expected  = 4'b0000;

    rls_pending     = 0;
    rda_pending     = 0;
    timeout_pending = 0;
    thre_pending    = 0;
    modem_pending   = 0;

    rls_delayed     = 0;
    rda_delayed     = 0;
    timeout_delayed = 0;
    thre_delayed    = 0;
    modem_delayed   = 0;

    iir_registered = 4'h1; // Sin interrupcion pendiente.
    irq_registered = 0;
  endfunction

  function void set_ier(input bit [3:0] value);
    ier = value;
  endfunction

  function void update_sources(
    input bit [7:0]     lsr_value,
    input int unsigned  rx_count,
    input int unsigned  rx_trigger,
    input bit           timeout_expired,
    input bit [3:0]     msr_deltas
  );
    if (!(rx_trigger inside {1, 4, 8, 14}))
      `uvm_fatal("IRQ_MODEL", "Nivel de disparo RX no valido (1, 4, 8 o 14)")

    lsr_expected        = lsr_value;
    rx_count_expected   = rx_count;
    rx_trigger_expected = rx_trigger;
    timeout_expected    = timeout_expired;
    msr_delta_expected  = msr_deltas;
  endfunction

  // Avanza un ciclo. Todas las decisiones consultan el estado ANTERIOR
  // de las banderas pendientes, como las asignaciones <= del RTL.
  function void tick(
    input bit read_lsr  = 0,
    input bit read_iir  = 0,
    input bit read_rbr  = 0,
    input bit write_thr = 0,
    input bit read_msr  = 0
  );
    bit s_rls, s_rda, s_timeout, s_thre, s_modem;
    bit rise_rls, rise_rda, rise_timeout, rise_thre, rise_modem;
    bit [3:0] next_iir;
    bit next_irq;
    bit next_rls, next_rda, next_timeout, next_thre, next_modem;

    // Equivalentes de rls_int, rda_int, ti_int, thre_int, ms_int.
    s_rls     = ier[2] && (|lsr_expected[4:1]);
    s_rda     = ier[0] && (rx_count_expected >= rx_trigger_expected);
    s_timeout = ier[0] && timeout_expected && (rx_count_expected != 0);
    s_thre    = ier[1] && lsr_expected[5];
    s_modem   = ier[3] && (|msr_delta_expected);

    // Flancos ascendentes: *_int & ~*_int_d.
    rise_rls     = s_rls     && !rls_delayed;
    rise_rda     = s_rda     && !rda_delayed;
    rise_timeout = s_timeout && !timeout_delayed;
    rise_thre    = s_thre    && !thre_delayed;
    rise_modem   = s_modem   && !modem_delayed;

    if      (rls_pending)     next_iir = 4'h6;
    else if (s_rda)           next_iir = 4'h4;
    else if (timeout_pending) next_iir = 4'hC;
    else if (thre_pending)    next_iir = 4'h2;
    else if (modem_pending)   next_iir = 4'h0;
    else                      next_iir = 4'h1;

    // int_o registrado: a diferencia de IIR, utiliza rda_int_pnd.
    // Se conserva la expresion PARTICULAR del RTL para THRE.
    if      (rls_pending)     next_irq = !read_lsr;
    else if (rda_pending)     next_irq = 1;
    else if (timeout_pending) next_irq = !read_rbr;
    else if (thre_pending)    next_irq = !(write_thr && read_iir);
    else if (modem_pending)   next_irq = !read_msr;
    else                      next_irq = 0;

  
    // Las limpiezas tienen prioridad sobre la deteccion de un flanco.
    next_rls = read_lsr ? 0 :
               rise_rls ? 1 :
               (rls_pending && ier[2]);

    // El RTL limpia RDA cuando el conteo PRE-lectura es el trigger exacto.
    next_rda = ((rx_count_expected == rx_trigger_expected) && read_rbr) ? 0 :
               rise_rda ? 1 :
               (rda_pending && ier[0]);

    next_timeout = read_rbr ? 0 :
                   rise_timeout ? 1 :
                   (timeout_pending && ier[0]);

    // El RTL revisa el IIR ANTERIOR a este flanco al atender THRE.
    next_thre = (write_thr ||
                 (read_iir && !iir_registered[0] &&
                  iir_registered[3:1] == 3'b001)) ? 0 :
                 rise_thre ? 1 :
                 (thre_pending && ier[1]);

    next_modem = read_msr ? 0 :
                 rise_modem ? 1 :
                 (modem_pending && ier[3]);

    // Efecto conjunto del flanco: se aplican todas las asignaciones
    // despues de calcular resultados a partir de estados anteriores.
    rls_pending     = next_rls;
    rda_pending     = next_rda;
    timeout_pending = next_timeout;
    thre_pending    = next_thre;
    modem_pending   = next_modem;

    rls_delayed     = s_rls;
    rda_delayed     = s_rda;
    timeout_delayed = s_timeout;
    thre_delayed    = s_thre;
    modem_delayed   = s_modem;

    iir_registered = next_iir;
    irq_registered = next_irq;
  endfunction