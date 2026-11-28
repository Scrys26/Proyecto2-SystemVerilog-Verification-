// Modelo de referencia de la línea serie, compara lo que se escribe en THR con lo que sale por stx. Y lo que entra por srx con lo que se lee en RBR.
// Lo usa el scoreboard, cada función se llama cuando un monitor reporta algo.
// Versión 2: las dos FIFOs tienen 16 posiciones como en el DUT, y se modela el loopback y la limpieza de FIFOs por FCR.
// También lleva el LSR esperado (DR, OE, PE, FE, BI) y lo revisa cada vez que se lee.

class uart_serie_model extends uvm_object;
  `uvm_object_utils(uart_serie_model)

  localparam int FIFO_DEPTH = 16;

  // El DUT tarda un par de ciclos en reflejar en LSR un cambio de la FIFO RX, y el bus toma el dato
  // un ciclo antes del ack. Si la FIFO cambió hace menos que esto, un LSR distinto no es error.
  localparam realtime LSR_WINDOW = 100ns; // 5 ciclos de 20 ns

  // Un carácter recibido: el dato, sus banderas de error y si vino fuera de tolerancia (skip)
  typedef struct {
    bit [7:0] data;
    bit       pe;
    bit       fe;
    bit       bi;
    bit       skip;
  } rx_char_t;

  // FIFO TX del DUT: bytes escritos en THR que todavía no empiezan a salir
  bit [7:0] tx_fifo[$];

  // Bytes que ya salieron de la FIFO y se están transmitiendo por stx (normalmente uno)
  bit [7:0] tx_shift[$];

  // FIFO RX del DUT: caracteres que entraron y todavía no se leyeron en RBR
  rx_char_t rx_fifo[$];

  // Caracteres que el monitor de srx ya vio pero que el DUT todavía no mete en su FIFO.
  // Entran a rx_fifo con el pulso rx_push, que es el momento exacto en que entran al DUT.
  rx_char_t rx_wait[$];

  // Pulsos rx_push que llegaron antes de que el monitor reportara la trama (pasa por pocos ciclos)
  int unsigned early_push;

  // En loopback: bytes que ya salieron de la FIFO TX y van por dentro hacia la FIFO RX
  bit [7:0] loop_shift[$];

  // MCR[4]: lo que se escribe en THR vuelve por dentro a RBR, stx se queda en 1 y srx no se usa
  bit loopback;

  // LCR[6]: con break activo stx se queda en 0 y los bytes que se transmiten no se pueden ver
  bit tx_break;

  // Hubo un overrun y todavía no se ha leído el siguiente byte de RBR
  bit after_overrun;

  // LSR esperado. OE, PE, FE y BI se quedan en 1 hasta que se lee LSR, igual que en el DUT.
  bit exp_oe, exp_pe, exp_fe, exp_bi;

  // El carácter al frente de la FIFO vino fuera de tolerancia: no se sabe qué errores vio el DUT
  bit err_unknown;

  // El error se esperaba porque el carácter anterior traía el mismo error. El RTL no lo vuelve
  // a avisar (detecta el flanco), aunque la especificación dice que cada carácter lo reporta.
  bit rep_pe, rep_fe, rep_bi;

  // Hora del último cambio en la FIFO RX (entra, se lee, se limpia o hay overrun)
  realtime last_rx_change;

  // Cuántos caracteres se compararon y cuántos no coincidieron
  int unsigned tx_checked;
  int unsigned tx_errors;
  int unsigned rx_checked;
  int unsigned rx_errors;
  int unsigned tx_overflows;
  int unsigned rx_overruns;
  int unsigned rx_skipped;
  int unsigned lsr_checked;
  int unsigned lsr_errors;

  function new(string name = "uart_serie_model");
    super.new(name);
  endfunction

  // Escritura en THR. En loopback también pasa por la FIFO TX, igual que en el DUT.
  function void write_thr(bit [7:0] data);
    // Con break el transmisor sigue trabajando por dentro, pero en stx no se ve nada: no hay qué comparar
    if (tx_break) return;

    if (tx_fifo.size() < FIFO_DEPTH) begin
      tx_fifo.push_back(data);
      return;
    end

    // FIFO llena: la especificación no dice qué pasa (AMB-06). En el RTL el byte nuevo
    // se escribe en la posición del más viejo, o sea, reemplaza al siguiente que iba a salir.
    tx_fifo[0] = data;
    tx_overflows++;
    `uvm_info("SB", $sformatf("FIFO TX llena: 0x%02h reemplaza al siguiente byte por salir (AMB-06)", data), UVM_MEDIUM)
  endfunction

  // El DUT acaba de sacar un byte de la FIFO TX para transmitirlo.
  // lcr es el formato en ese momento: en loopback dice cuántos bits van a llegar a RBR.
  function void tx_pop(bit [7:0] lcr);
    if (tx_fifo.size() == 0) begin
      `uvm_error("SB", "El DUT sacó un byte de la FIFO TX pero la FIFO del modelo está vacía")
      tx_errors++;
      return;
    end
    if (loopback)
      loop_shift.push_back(tx_fifo.pop_front() & mask_of(lcr));
    else
      tx_shift.push_back(tx_fifo.pop_front());
  endfunction

  // El DUT acaba de meter un carácter en la FIFO RX. En loopback viene de la vuelta por dentro;
  // si no, es el que ya reportó el monitor de srx.
  function void rx_push();
    rx_char_t c;
    if (loopback) begin
      if (loop_shift.size() == 0) begin
        `uvm_error("SB", "En loopback entró un byte a la FIFO RX sin que saliera ninguno de la FIFO TX")
        rx_errors++;
        return;
      end
      c = '{data: loop_shift.pop_front(), default: 0};
      rx_in(c);
      return;
    end

    // El monitor todavía no reporta la trama: se guarda el pulso para cuando llegue
    if (rx_wait.size() == 0) begin
      early_push++;
      return;
    end
    rx_in(rx_wait.pop_front());
  endfunction

  // El monitor de stx vio salir un carácter, revisar si coincide con lo que se esperaba
  function void check_stx(serie_item it);
    bit [7:0] expected;
    bit [7:0] mask;

    if (tx_shift.size() == 0) begin
      `uvm_error("SB", $sformatf("Salió 0x%02h por stx pero nadie había escrito en THR", it.data))
      tx_errors++;
      return;
    end

    expected = tx_shift.pop_front();

    // Con menos de 8 bits de dato, los bits de arriba del byte no se transmiten
    mask = mask_of(it.lcr);

    tx_checked++;
    if ((it.data & mask) != (expected & mask)) begin
      `uvm_error("SB", $sformatf("TX: se esperaba 0x%02h y salió 0x%02h por stx", expected & mask, it.data & mask))
      tx_errors++;
    end
  endfunction

  // El monitor de srx vio una trama completa: espera al pulso rx_push para entrar a la FIFO.
  // skip = 1 si vino fuera de tolerancia: se cuenta su lugar en la FIFO pero no su dato ni sus errores.
  function void got_srx(serie_item it);
    rx_char_t c;
    // En loopback el receptor no escucha srx
    if (loopback) return;
    c = '{data: it.data & mask_of(it.lcr), pe: it.pe, fe: it.fe, bi: it.bi, skip: it.baud_out};
    if (early_push > 0) begin
      early_push--;
      rx_in(c);
    end else
      rx_wait.push_back(c);
  endfunction

  // Un carácter entra a la FIFO RX, venga de srx o de la vuelta del loopback
  function void rx_in(rx_char_t c);
    last_rx_change = $realtime;
    if (rx_fifo.size() < FIFO_DEPTH) begin
      rx_fifo.push_back(c);
      // Si la FIFO estaba vacía, este carácter queda al frente y sus errores se ven en LSR
      if (rx_fifo.size() == 1)
        reveal_head(0, 0, 0);
      return;
    end

    // Overrun: según la especificación el carácter nuevo se pierde, la FIFO queda igual y se prende OE
    rx_overruns++;
    after_overrun = 1;
    exp_oe        = 1;
    `uvm_info("SB", $sformatf("Overrun: FIFO RX llena, se pierde 0x%02h", c.data), UVM_MEDIUM)
  endfunction

  // Un carácter nuevo quedó al frente de la FIFO RX: sus errores pasan al LSR esperado.
  // prev_* son los errores del carácter que se acaba de leer, para saber si el error se repite.
  function void reveal_head(bit prev_pe, bit prev_fe, bit prev_bi);
    rx_char_t h;
    if (rx_fifo.size() == 0) return;
    h = rx_fifo[0];
    if (h.skip) begin
      err_unknown = 1;
      return;
    end
    if (h.pe) begin exp_pe = 1; rep_pe |= prev_pe; end
    if (h.fe) begin exp_fe = 1; rep_fe |= prev_fe; end
    if (h.bi) begin exp_bi = 1; rep_bi |= prev_bi; end
  endfunction

  // Cuando se lee un byte de RBR, se compara con lo que se esperaba
  function void read_rbr(bit [7:0] data);
    rx_char_t c;
    bit [7:0] expected;

    if (rx_fifo.size() == 0) begin
      `uvm_error("SB", $sformatf("Se leyó 0x%02h de RBR pero no había entrado nada por srx", data))
      rx_errors++;
      return;
    end

    c        = rx_fifo.pop_front();
    expected = c.data;
    last_rx_change = $realtime;

    // El siguiente queda al frente y sus errores pasan al LSR. Si el que se fue venía fuera de
    // tolerancia no se sabe qué errores vio el DUT, así que tampoco se sabe si el siguiente los repite.
    reveal_head(c.pe && !c.skip, c.fe && !c.skip, c.bi && !c.skip);
    if (c.skip && rx_fifo.size() > 0)
      err_unknown = 1;

    // Fuera de tolerancia el DUT puede leer otra cosa y está bien: solo se cuenta.
    // Simplificación: se supone que esa trama sí metió un byte en la FIFO.
    if (c.skip) begin
      rx_skipped++;
      after_overrun = 0;
      return;
    end

    rx_checked++;
    if (data != expected) begin
      // Si justo antes hubo overrun, el fallo probablemente es del DUT: en el RTL el carácter
      // que no cabe se escribe encima del más viejo de la FIFO
      if (after_overrun)
        `uvm_error("SB_DUT", $sformatf("RX después de overrun: se esperaba 0x%02h y se leyó 0x%02h (el DUT sobrescribió la FIFO)", expected, data))
      else
        `uvm_error("SB", $sformatf("RX: se esperaba leer 0x%02h de RBR y se leyó 0x%02h", expected, data))
      rx_errors++;
    end
    after_overrun = 0;
  endfunction

  // Lectura de LSR: se compara con el esperado y, como en el DUT, se limpian OE, PE, FE y BI.
  // THRE y TEMT no se revisan: cambian en ciclos que el modelo no sigue (el plan pide una ventana).
  function void read_lsr(bit [7:0] data);
    string    names[5] = '{"DR", "OE", "PE", "FE", "BI"};
    bit [4:0] repeated;
    bit [4:0] keep;
    bit [7:0] exp;
    bit       near;

    exp      = lsr_expected();
    near     = ($realtime - last_rx_change) < LSR_WINDOW;
    repeated = {rep_bi, rep_fe, rep_pe, 2'b00};
    keep     = '0;
    lsr_checked++;

    for (int i = 0; i <= 4; i++) begin
      if (data[i] == exp[i]) continue;
      if (i >= 2 && err_unknown) continue;
      // Justo después de un cambio en la FIFO el DUT todavía no lo refleja. Si esperábamos un
      // error que aún no aparece, el DUT lo va a prender después: se guarda para la próxima lectura.
      if (near) begin
        keep[i] = exp[i];
        continue;
      end
      lsr_mismatch(names[i], data[i], exp[i], repeated[i]);
    end

    // Leer LSR apaga OE, PE, FE y BI, salvo los que el DUT todavía no alcanzaba a mostrar
    exp_oe = keep[1];
    exp_pe = keep[2];
    exp_fe = keep[3];
    exp_bi = keep[4];
    rep_pe &= keep[2];
    rep_fe &= keep[3];
    rep_bi &= keep[4];
    err_unknown = 0;
  endfunction

  // Si el DUT no avisó un error que traía también el carácter anterior, es lo que hace el RTL
  // (solo ve el flanco) y no lo que pide la especificación: se marca como posible error del DUT.
  function void lsr_mismatch(string name, bit got, bit exp, bit repeated);
    lsr_errors++;
    if (!got && repeated)
      `uvm_error("SB_DUT", $sformatf("LSR.%s: el carácter traía error igual que el anterior y el DUT no lo avisó", name))
    else
      `uvm_error("SB", $sformatf("LSR.%s: se esperaba %0b y se leyó %0b", name, exp, got))
  endfunction

  // LSR esperado en este momento. THRE (bit 5), TEMT (bit 6) y el bit 7 son aproximados:
  // no siguen el retraso de un carácter que el RTL le pone a THRE.
  function bit [7:0] lsr_expected();
    bit [7:0] lsr;
    lsr[0] = (rx_fifo.size() > 0);
    lsr[1] = exp_oe;
    lsr[2] = exp_pe;
    lsr[3] = exp_fe;
    lsr[4] = exp_bi;
    lsr[5] = (tx_fifo.size() == 0);
    lsr[6] = lsr[5] && (tx_shift.size() == 0) && (loop_shift.size() == 0);
    lsr[7] = exp_oe || exp_pe || exp_fe || exp_bi;
    return lsr;
  endfunction

  // Escritura en FCR: bit 1 limpia la FIFO RX y bit 2 la TX.
  // Lo que ya se está transmitiendo sigue saliendo, por eso tx_shift no se toca.
  function void write_fcr(bit [7:0] data);
    if (data[1]) begin
      rx_fifo.delete();
      rx_wait.delete();
      after_overrun  = 0;
      last_rx_change = $realtime;
    end
    if (data[2])
      tx_fifo.delete();
  endfunction

  // Escritura en LCR: solo interesa el bit de break. Al prenderlo, lo que estaba pendiente
  // sale escondido detrás del break, así que se deja de esperar.
  function void write_lcr(bit [7:0] data);
    if (data[6] && !tx_break) begin
      tx_fifo.delete();
      tx_shift.delete();
    end
    tx_break = data[6];
  endfunction

  // Escritura en MCR: solo interesa el bit de loopback
  function void write_mcr(bit [7:0] data);
    loopback = data[4];
  endfunction

  // Devuelve cuántos bytes hay en la FIFO RX del modelo
  function int unsigned rx_level();
    return unsigned'(rx_fifo.size());
  endfunction

  // Cuántos bits de dato tiene el formato: los de arriba no viajan por la línea
  function bit [7:0] mask_of(bit [7:0] lcr);
    return 8'hFF >> (3 - lcr[1:0]);
  endfunction

  // Al final de la prueba, imprime cuántos caracteres se compararon y cuántos fallaron
  function void report();
    `uvm_info("SB", $sformatf("TX: %0d comparados, %0d con error, %0d escrituras con la FIFO llena", tx_checked, tx_errors, tx_overflows), UVM_LOW)
    `uvm_info("SB", $sformatf("RX: %0d comparados, %0d con error, %0d overruns, %0d fuera de tolerancia sin comparar", rx_checked, rx_errors, rx_overruns, rx_skipped), UVM_LOW)
    `uvm_info("SB", $sformatf("LSR: %0d lecturas revisadas, %0d con error", lsr_checked, lsr_errors), UVM_LOW)

    // Si quedaron bytes en las colas, algo se mandó y nunca llegó al otro lado
    if (tx_fifo.size() + tx_shift.size() + loop_shift.size() != 0)
      `uvm_error("SB", $sformatf("Quedaron %0d bytes escritos en THR que nunca llegaron al otro lado", tx_fifo.size() + tx_shift.size() + loop_shift.size()))
    if (rx_fifo.size() + rx_wait.size() != 0)
      `uvm_error("SB", $sformatf("Quedaron %0d bytes que entraron y nunca se leyeron de RBR", rx_fifo.size() + rx_wait.size()))
  endfunction

  // Cuando hay un reset, se borran las colas de bytes pendientes; los contadores se quedan para el reporte final
  function void reset();
    tx_fifo.delete();
    tx_shift.delete();
    loop_shift.delete();
    rx_fifo.delete();
    rx_wait.delete();
    early_push    = 0;
    loopback      = 0;
    tx_break      = 0;
    after_overrun = 0;
    {exp_oe, exp_pe, exp_fe, exp_bi} = '0;
    {rep_pe, rep_fe, rep_bi}         = '0;
    err_unknown = 0;
  endfunction

endclass : uart_serie_model
