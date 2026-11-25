// Caracter la secuencia lo sortea y arma su trama. Usada también por el monitor para reportar lo que vio pasar.

typedef enum bit [1:0] {SER_OK, SER_PARITY_ERR, SER_FRAME_ERR, SER_BREAK} serie_err_e; // la secuencia lo sortea y arma su trama.
typedef enum bit       {SER_DIR_TX, SER_DIR_RX} serie_dir_e;
class serie_item extends uvm_sequence_item; // lo usa el monitor para decir en qué cable vio el carácter.
  `uvm_object_utils(serie_item)

  // Lo que decide la secuencia al sortear
  rand bit [7:0]    data;
  rand serie_err_e  err; // ¿Error? 
  rand bit          glitch; // ¿Pulso de ruido? 
  rand bit          baud_out; // ¿Velocidad dentro del rango?
  rand int          baud_dev_pct;
  rand int unsigned idle_bits; // bits de espera

  // Formato de línea con que se armó o se leyó el carácter
  bit [7:0]    lcr; // Line Control Register
  bit [15:0]   dl; // Divisor Latch

  // La trama ya armada: cada posición es un nivel de la línea y cuántos ciclos dura.
  // El driver solo recorre estas dos listas.
  bit          seg_level[$];
  int unsigned seg_clks[$];

  // Lo que llena el monitor
  serie_dir_e  dir;
  bit          pe, fe, bi;

  // Las restricciones leen sus perillas de aquí. La secuencia lo asigna antes de sortear.
  config_serie cfg;

  // Qué tipo de trama sale, según los porcentajes del cfg
  constraint c_err {
    err dist { SER_OK         := 100 - cfg.ser_parity_err_pct - cfg.ser_frame_err_pct - cfg.ser_break_pct,
               SER_PARITY_ERR := cfg.ser_parity_err_pct,
               SER_FRAME_ERR  := cfg.ser_frame_err_pct,
               SER_BREAK      := cfg.ser_break_pct };
  }
  
  // En un break el UART guarda 0 como dato, así que el item también lleva 0
  constraint c_break_data { (err == SER_BREAK) -> data == 8'h00; }

  // Con el primer bit de dato en 1, un error de trama nunca se confunde con un break
  constraint c_frame_data { (err == SER_FRAME_ERR) -> data[0] == 1'b1; }

  constraint c_glitch {
    glitch dist { 1 := cfg.ser_glitch_pct, 0 := 100 - cfg.ser_glitch_pct };
  }

  // Dentro de la tolerancia el UART lee bien; fuera de ella puede fallar
  constraint c_baud {
    baud_out dist { 1 := cfg.ser_baud_out_pct, 0 := 100 - cfg.ser_baud_out_pct };
    if (baud_out)
      baud_dev_pct inside {[-int'(cfg.ser_baud_dev_max) : -3], [3 : int'(cfg.ser_baud_dev_max)]};
    else
      baud_dev_pct inside {[-2 : 2]};
  }

  // La espera casi siempre es corta; de vez en cuando es larga
  constraint c_idle {
    idle_bits dist { [0 : cfg.ser_delay_max]                         :/ 100 - cfg.ser_delay_tail_pct,
                     [cfg.ser_delay_max + 1 : cfg.ser_delay_abs_max] :/ cfg.ser_delay_tail_pct };
  }
  function new(string name = "serie_item");
    super.new(name);
  endfunction

  // Sin el cfg las restricciones no tienen de dónde leer, así que se para todo
  function void pre_randomize();
    if (cfg == null)
      `uvm_fatal("CFG", "serie_item sin config_serie: asignar cfg antes de randomize()")
  endfunction

  // Llamado por la secuencia después de sortear, con el LCR y el DL que tiene el UART.
  // Arma la trama como una lista de segmentos: nivel de la línea y cuántos ciclos dura.
  function void build_frame(bit [7:0] lcr_now, bit [15:0] dl_now);
    int unsigned bit_clks;
    int unsigned nbits;
    bit          p;

    lcr = lcr_now;
    dl  = dl_now;
    seg_level.delete();
    seg_clks.delete();

    // Con DL en 0 el UART no recibe nada, así que no se manda trama
    if (dl_now == 0) return;

    // Cada bit dura 16 x DL ciclos, estirado o encogido según la desviación sorteada
    bit_clks = (16 * dl_now * (100 + baud_dev_pct)) / 100;
    nbits    = lcr_now[1:0] + 5;

    // Reposo antes de la trama
    add_seg(1'b1, idle_bits * 16 * dl_now);

    // Un pulso de un cuarto de bit: el UART lo revisa a mitad del bit y lo descarta
    if (glitch) begin
      add_seg(1'b0, 4 * dl_now);
      add_seg(1'b1, 16 * dl_now);
    end

    // Break: la línea en 0 durante dos caracteres completos, y luego de vuelta a reposo
    if (err == SER_BREAK) begin
      add_seg(1'b0, 2 * 12 * bit_clks);
      add_seg(1'b1, 16 * dl_now);
      return;
    end

    // Bit de inicio
    add_seg(1'b0, bit_clks);

    // Bits de dato, del menos significativo al más significativo
    for (int i = 0; i < nbits; i++)
      add_seg(data[i], bit_clks);

    // Paridad, solo si está activada en el LCR
    if (lcr_now[3]) begin
      p = calc_parity(lcr_now, data, nbits);
      if (err == SER_PARITY_ERR) p = ~p;
      add_seg(p, bit_clks);
    end

    // El UART solo revisa el primer bit de parada, así que el error de trama va ahí
    add_seg(err == SER_FRAME_ERR ? 1'b0 : 1'b1, bit_clks);

    // Segundo bit de parada: medio bit si son 5 bits de dato, uno entero si no
    if (lcr_now[2])
      add_seg(1'b1, nbits == 5 ? bit_clks / 2 : bit_clks);

    // Después de un error de trama la línea tiene que volver a 1 antes del siguiente carácter
    if (err == SER_FRAME_ERR)
      add_seg(1'b1, 16 * dl_now);
  endfunction

  // LCR[4] elige par o impar y LCR[5] fija el bit. Es static para que el monitor también la use.
  static function bit calc_parity(bit [7:0] lcr_now, bit [7:0] d, int unsigned nbits);
    bit x;
    x = 1'b0;
    for (int i = 0; i < nbits; i++)
      x = x ^ d[i];
    if (lcr_now[5])
      return ~lcr_now[4];
    if (lcr_now[4])
      return x;
    return ~x;
  endfunction

  function void add_seg(bit level, int unsigned clks);
    if (clks == 0) return;
    seg_level.push_back(level);
    seg_clks.push_back(clks);
  endfunction

  function string convert2string();
    return $sformatf("dir=%s data=0x%02h err=%s glitch=%0b baud=%0d%% idle=%0d lcr=0x%02h dl=%0d pe=%0b fe=%0b bi=%0b",
                     dir.name(), data, err.name(), glitch, baud_dev_pct, idle_bits,
                     lcr, dl, pe, fe, bi);
  endfunction

endclass : serie_item