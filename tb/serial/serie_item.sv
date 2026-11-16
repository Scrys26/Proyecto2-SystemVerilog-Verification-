// Un carácter de la línea serie. La secuencia RX lo genera y arma la trama; los monitores de stx y srx lo publican.

typedef enum bit [1:0] {SER_OK, SER_PARITY_ERR, SER_FRAME_ERR, SER_BREAK} serie_err_e;
typedef enum bit       {SER_DIR_TX, SER_DIR_RX} serie_dir_e;

class serie_item extends uvm_sequence_item;
  `uvm_object_utils(serie_item)

  // Lo que decide la secuencia al aleatorizar
  rand bit [7:0]    data;
  rand serie_err_e  err;
  rand bit          glitch;
  rand int unsigned glitch_ticks;
  rand bit          baud_out;
  rand int          baud_dev_pct;
  rand int unsigned idle_bits;

  // Formato de línea con que se armó o se leyó el carácter
  bit [7:0]    lcr;
  bit [15:0]   dl;

  // La trama ya armada para el driver: cada segmento es un nivel de la línea y cuántos ciclos de reloj dura.
  // Así el driver no tiene que saber nada de paridad ni de errores, solo copia esto a srx.
  bit          seg_level[$];
  int unsigned seg_clks[$];

  // Lo que vio el monitor. Se usan banderas separadas porque una misma trama puede traer PE y FE juntos.
  serie_dir_e  dir;
  bit          pe, fe, bi;
  // El monitor no sabe qué desviación quiso meter la secuencia. Lo que sí ve es si un borde cayó cerca del
  // punto de muestreo; en ese caso lo que leyó el UART depende de la fase y el scoreboard no compara el dato.
  bit          marginal;

  // La secuencia tiene que asignar este handle antes de randomize(), porque las restricciones leen sus knobs.
  config_serie cfg;

  constraint c_err {
    err dist { SER_OK         := 100 - cfg.ser_parity_err_pct - cfg.ser_frame_err_pct - cfg.ser_break_pct,
               SER_PARITY_ERR := cfg.ser_parity_err_pct,
               SER_FRAME_ERR  := cfg.ser_frame_err_pct,
               SER_BREAK      := cfg.ser_break_pct };
  }

  // En un break el receptor mete 0 como dato en la FIFO, entonces dejamos el item igual para que cuadre.
  constraint c_break_data { (err == SER_BREAK) -> data == 8'h00; }

  // Un error de trama con todo en 0 dura lo mismo que un break y el receptor lo puede tomar como break.
  // Con el primer bit de dato en 1 los dos casos nunca se confunden.
  constraint c_frame_data { (err == SER_FRAME_ERR) -> data[0] == 1'b1; }

  // El receptor revisa el bit de inicio a la mitad del bit y, si la línea ya volvió a 1, lo descarta.
  // Por eso un pulso de hasta un cuarto de bit nunca se toma como dato.
  constraint c_glitch {
    glitch dist { 1 := cfg.ser_glitch_pct, 0 := 100 - cfg.ser_glitch_pct };
    glitch_ticks inside {[1 : UART_GLITCH_MAX_TICKS]};
  }

  // Dentro de la tolerancia el dato siempre llega bien. Fuera de ella puede llegar bien o con error
  // de trama según dónde caiga el muestreo; el monitor lo marca como marginal.
  constraint c_baud {
    baud_out dist { 1 := cfg.ser_baud_out_pct, 0 := 100 - cfg.ser_baud_out_pct };
    if (baud_out)
      baud_dev_pct inside {[-int'(cfg.ser_baud_dev_max) : -(UART_BAUD_TOL_PCT + 1)],
                           [UART_BAUD_TOL_PCT + 1 : int'(cfg.ser_baud_dev_max)]};
    else
      baud_dev_pct inside {[-UART_BAUD_TOL_PCT : UART_BAUD_TOL_PCT]};
  }

  // Las esperas largas alargan mucho la simulación, así que por defecto casi siempre son cortas.
  // Siguen siendo posibles con ser_delay_tail_pct, y son las que provocan el timeout.
  constraint c_idle {
    idle_bits dist { [0 : cfg.ser_delay_max]                         :/ 100 - cfg.ser_delay_tail_pct,
                     [cfg.ser_delay_max + 1 : cfg.ser_delay_abs_max] :/ cfg.ser_delay_tail_pct };
  }

  function new(string name = "serie_item");
    super.new(name);
  endfunction

  function void pre_randomize();
    if (cfg == null)
      `uvm_fatal("CFG", "serie_item sin config_serie: la secuencia debe asignar cfg antes de randomize()")
  endfunction

  // La secuencia llama esto después de randomize(), con el LCR y el DL que tiene el espejo del RAL.
  function void build_frame(bit [7:0] lcr_now, bit [15:0] dl_now);
    int unsigned bit_clks_nom;
    int unsigned nbits;
    int unsigned break_bits;
    bit          p;
    bit          sym_level[$];
    int unsigned sym_halves[$];
    real         half_clks;
    int unsigned halves_done;
    int unsigned edge_prev;
    int unsigned edge_next;

    lcr = lcr_now;
    dl  = dl_now;
    seg_level.delete();
    seg_clks.delete();

    // Con DL = 0 el UART no recibe nada, así que no se arma trama y la línea se queda en reposo.
    if (dl_now == 0) return;

    bit_clks_nom = UART_OVERSAMPLE * dl_now;
    nbits        = lcr_now[1:0] + 5;

    add_seg(1'b1, idle_bits * bit_clks_nom);

    // Después del glitch la línea se queda un bit entero en 1 para que el receptor vuelva a reposo
    // antes del bit de inicio de verdad.
    if (glitch) begin
      add_seg(1'b0, glitch_ticks * dl_now);
      add_seg(1'b1, bit_clks_nom);
    end

    // El receptor marca break cuando la línea pasa en 0 más de lo que dura un carácter completo.
    // Se calcula con el carácter más largo posible para este formato y se deja en 0 varias veces eso.
    if (err == SER_BREAK) begin
      break_bits = 1 + nbits + lcr_now[3] + 2;
      add_seg(1'b0, UART_BREAK_CHARS * break_bits * bit_clks_nom);
      add_seg(1'b1, bit_clks_nom);
      return;
    end

    // La trama se arma en medios bits porque con 5 bits de dato el UART usa 1.5 bits de parada.
    sym_level.push_back(1'b0);
    sym_halves.push_back(2);
    for (int i = 0; i < nbits; i++) begin
      sym_level.push_back(data[i]);
      sym_halves.push_back(2);
    end
    if (lcr_now[3]) begin
      p = calc_parity(lcr_now, data, nbits);
      if (err == SER_PARITY_ERR) p = ~p;
      sym_level.push_back(p);
      sym_halves.push_back(2);
    end
    // El receptor solo revisa el primer bit de parada, así que el error de trama se mete en ese.
    sym_level.push_back(err == SER_FRAME_ERR ? 1'b0 : 1'b1);
    sym_halves.push_back(2);
    if (lcr_now[2]) begin
      sym_level.push_back(1'b1);
      sym_halves.push_back(nbits == 5 ? 1 : 2);
    end

    // Los bordes se calculan acumulados desde el inicio de la trama. Si se redondeara cada bit por
    // separado, con DL pequeño una desviación de 2 % se perdería y todos los bits saldrían iguales.
    half_clks   = bit_clks_nom * (100.0 + baud_dev_pct) / 200.0;
    halves_done = 0;
    edge_prev   = 0;
    foreach (sym_level[i]) begin
      halves_done += sym_halves[i];
      edge_next = $rtoi(halves_done * half_clks + 0.5);
      add_seg(sym_level[i], edge_next - edge_prev);
      edge_prev = edge_next;
    end

    // Después de un error de trama el receptor espera ver la línea en 1 antes de aceptar otro carácter.
    if (err == SER_FRAME_ERR) add_seg(1'b1, bit_clks_nom);
  endfunction

  // LCR[4] elige par o impar y LCR[5] fija el bit (stick), igual que en la tabla de LCR de la especificación.
  // Es static porque el monitor también la usa para revisar la paridad que observa.
  static function bit calc_parity(bit [7:0] lcr_now, bit [7:0] d, int unsigned nbits);
    bit x = 1'b0;
    bit p;
    for (int i = 0; i < nbits; i++) x ^= d[i];
    case ({lcr_now[4], lcr_now[5]})
      2'b00: p = ~x;
      2'b10: p =  x;
      2'b01: p = 1'b1;
      2'b11: p = 1'b0;
    endcase
    return p;
  endfunction

  local function void add_seg(bit level, int unsigned clks);
    if (clks == 0) return;
    seg_level.push_back(level);
    seg_clks.push_back(clks);
  endfunction

  function string convert2string();
    return $sformatf("dir=%s data=0x%02h err=%s glitch=%0b(%0d) baud=%0d%% idle=%0d lcr=0x%02h dl=%0d segs=%0d pe=%0b fe=%0b bi=%0b marginal=%0b",
                     dir.name(), data, err.name(), glitch, glitch_ticks, baud_dev_pct, idle_bits,
                     lcr, dl, seg_level.size(), pe, fe, bi, marginal);
  endfunction

endclass : serie_item