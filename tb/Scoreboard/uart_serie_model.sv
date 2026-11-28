// Modelo de referencia de la línea serie, compara lo que se escribe en THR con lo que sale por stx. Y lo que entra por srx con lo que se lee en RBR.
// Lo usa el scoreboard, cada función se llama cuando un monitor reporta algo.
// Versión 2: las dos FIFOs tienen 16 posiciones como en el DUT, y se modela el loopback y la limpieza de FIFOs por FCR.

class uart_serie_model extends uvm_object;
  `uvm_object_utils(uart_serie_model)

  localparam int FIFO_DEPTH = 16;

  // FIFO TX del DUT: bytes escritos en THR que todavía no empiezan a salir
  bit [7:0] tx_fifo[$];

  // Bytes que ya salieron de la FIFO y se están transmitiendo por stx (normalmente uno)
  bit [7:0] tx_shift[$];

  // FIFO RX del DUT: bytes que entraron y todavía no se leyeron en RBR
  bit [7:0] rx_fifo[$];

  // Va junto con rx_fifo: 1 si ese byte llegó fuera de tolerancia de baudios y no se compara
  bit       rx_skip[$];

  // En loopback: bytes que ya salieron de la FIFO TX y van por dentro hacia la FIFO RX
  bit [7:0] loop_shift[$];

  // MCR[4]: lo que se escribe en THR vuelve por dentro a RBR, stx se queda en 1 y srx no se usa
  bit loopback;

  // LCR[6]: con break activo stx se queda en 0 y los bytes que se transmiten no se pueden ver
  bit tx_break;

  // Hubo un overrun y todavía no se ha leído el siguiente byte de RBR
  bit after_overrun;

  // Cuántos caracteres se compararon y cuántos no coincidieron
  int unsigned tx_checked;
  int unsigned tx_errors;
  int unsigned rx_checked;
  int unsigned rx_errors;
  int unsigned tx_overflows;
  int unsigned rx_overruns;
  int unsigned rx_skipped;

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

  // El DUT acaba de meter un byte en la FIFO RX. Solo importa en loopback, porque ese byte
  // no se ve en srx; fuera de loopback lo que entra ya lo reporta el monitor de srx.
  function void rx_push();
    if (!loopback) return;
    if (loop_shift.size() == 0) begin
      `uvm_error("SB", "En loopback entró un byte a la FIFO RX sin que saliera ninguno de la FIFO TX")
      rx_errors++;
      return;
    end
    rx_in(loop_shift.pop_front(), 0);
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

  // Cuando el monitor de srx vio entrar un carácter, se agrega a la FIFO RX del modelo
  function void got_srx(serie_item it);
    // En loopback el receptor no escucha srx
    if (loopback) return;
    rx_in(it.data & mask_of(it.lcr), it.baud_out);
  endfunction

  // Un byte llega a la FIFO RX, venga de srx o de la vuelta del loopback
  // skip = 1 si la trama vino fuera de tolerancia: se cuenta su lugar en la FIFO pero no su dato
  function void rx_in(bit [7:0] data, bit skip);
    if (rx_fifo.size() < FIFO_DEPTH) begin
      rx_fifo.push_back(data);
      rx_skip.push_back(skip);
      return;
    end

    // Overrun: según la especificación el carácter nuevo se pierde y la FIFO queda igual.
    // Más adelante el modelo revisa que el DUT prenda OE en LSR.
    rx_overruns++;
    after_overrun = 1;
    `uvm_info("SB", $sformatf("Overrun: FIFO RX llena, se pierde 0x%02h", data), UVM_MEDIUM)
  endfunction

  // Cuando se lee un byte de RBR, se compara con lo que se esperaba
  function void read_rbr(bit [7:0] data);
    bit [7:0] expected;
    bit       skip;

    if (rx_fifo.size() == 0) begin
      `uvm_error("SB", $sformatf("Se leyó 0x%02h de RBR pero no había entrado nada por srx", data))
      rx_errors++;
      return;
    end

    expected = rx_fifo.pop_front();
    skip     = rx_skip.pop_front();

    // Fuera de tolerancia el DUT puede leer otra cosa y está bien: solo se cuenta.
    // Simplificación: se supone que esa trama sí metió un byte en la FIFO.
    if (skip) begin
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

  // Escritura en FCR: bit 1 limpia la FIFO RX y bit 2 la TX.
  // Lo que ya se está transmitiendo sigue saliendo, por eso tx_shift no se toca.
  function void write_fcr(bit [7:0] data);
    if (data[1]) begin
      rx_fifo.delete();
      rx_skip.delete();
      after_overrun = 0;
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

    // Si quedaron bytes en las colas, algo se mandó y nunca llegó al otro lado
    if (tx_fifo.size() + tx_shift.size() + loop_shift.size() != 0)
      `uvm_error("SB", $sformatf("Quedaron %0d bytes escritos en THR que nunca llegaron al otro lado", tx_fifo.size() + tx_shift.size() + loop_shift.size()))
    if (rx_fifo.size() != 0)
      `uvm_error("SB", $sformatf("Quedaron %0d bytes que entraron y nunca se leyeron de RBR", rx_fifo.size()))
  endfunction

  // Cuando hay un reset, se borran las colas de bytes pendientes; los contadores se quedan para el reporte final
  function void reset();
    tx_fifo.delete();
    tx_shift.delete();
    loop_shift.delete();
    rx_fifo.delete();
    rx_skip.delete();
    loopback      = 0;
    tx_break      = 0;
    after_overrun = 0;
  endfunction

endclass : uart_serie_model
