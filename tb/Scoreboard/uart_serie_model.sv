// Modelo de referencia de la línea serie, compara lo que se escribe en THR con lo que sale por stx. Y lo que entra por srx con lo que se lee en RBR. 
// Lo usa el scoreboard, cada función se llama cuando un monitor reporta algo.

class uart_serie_model extends uvm_object;
  `uvm_object_utils(uart_serie_model)

  // Cola de bytes que se escribieron en THR y todavía no salieron por stx
  bit [7:0] tx_expected[$];

  // Cola de bytes que entraron por srx y todavía no se leyeron en RBR
  bit [7:0] rx_expected[$];

  // Cuántos caracteres se compararon y cuántos no coincidieron
  int unsigned tx_checked;
  int unsigned tx_errors;
  int unsigned rx_checked;
  int unsigned rx_errors;

  function new(string name = "uart_serie_model");
    super.new(name);
  endfunction

  // Cuando se escribe un byte en THR se agrega a la cola de bytes esperados
  function void write_thr(bit [7:0] data);
    tx_expected.push_back(data);
  endfunction

  // El monitor de stx vio salir un carácter, revisar si coincide con lo que se esperaba
  function void check_stx(serie_item it);
    bit [7:0] expected;
    bit [7:0] mask;

    if (tx_expected.size() == 0) begin
      `uvm_error("SB", $sformatf("Salió 0x%02h por stx pero nadie había escrito en THR", it.data))
      tx_errors++;
      return;
    end

    expected = tx_expected.pop_front();

    // Con menos de 8 bits de dato, los bits de arriba del byte no se transmiten
    mask = 8'hFF >> (3 - it.lcr[1:0]);

    tx_checked++;
    if ((it.data & mask) != (expected & mask)) begin
      `uvm_error("SB", $sformatf("TX: se esperaba 0x%02h y salió 0x%02h por stx", expected & mask, it.data & mask))
      tx_errors++;
    end
  endfunction

  // Cuando el monitor de srx vio entrar un carácter, se agrega a la cola de bytes esperados para leer en RBR
  function void got_srx(serie_item it);
    bit [7:0] mask;
    mask = 8'hFF >> (3 - it.lcr[1:0]);
    rx_expected.push_back(it.data & mask);
  endfunction

  // Cuando se lee un byte de RBR, se compara con lo que se esperaba
  function void read_rbr(bit [7:0] data);
    bit [7:0] expected;

    if (rx_expected.size() == 0) begin
      `uvm_error("SB", $sformatf("Se leyó 0x%02h de RBR pero no había entrado nada por srx", data))
      rx_errors++;
      return;
    end

    expected = rx_expected.pop_front();

    rx_checked++;
    if (data != expected) begin
      `uvm_error("SB", $sformatf("RX: se esperaba leer 0x%02h de RBR y se leyó 0x%02h", expected, data))
      rx_errors++;
    end
  endfunction

  // Devuelve cuántos bytes entraron por srx y todavía no se leyeron de RBR
  function int unsigned rx_level();
    return rx_expected.size();
  endfunction

  // Al final de la prueba, imprime cuántos caracteres se compararon y cuántos fallaron
  function void report();
    `uvm_info("SB", $sformatf("TX: %0d comparados, %0d con error", tx_checked, tx_errors), UVM_LOW)
    `uvm_info("SB", $sformatf("RX: %0d comparados, %0d con error", rx_checked, rx_errors), UVM_LOW)

    // Si quedaron bytes en las colas, algo se mandó y nunca llegó al otro lado
    if (tx_expected.size() != 0)
      `uvm_error("SB", $sformatf("Quedaron %0d bytes escritos en THR que nunca salieron por stx", tx_expected.size()))
    if (rx_expected.size() != 0)
      `uvm_error("SB", $sformatf("Quedaron %0d bytes que entraron por srx y nunca se leyeron de RBR", rx_expected.size()))
  endfunction

  // Cuando hay un reset, se borran las colas de bytes pendientes y los contadores de comparaciones y errores
  function void reset();
    tx_expected.delete();
    rx_expected.delete();
  endfunction

endclass : uart_serie_model