// Modelo de referencia de la línea serie: compara lo que se escribe en THR con lo que sale por stx.
// Lo usa el scoreboard; cada función se llama cuando un monitor reporta algo.

class uart_serie_model extends uvm_object;
  `uvm_object_utils(uart_serie_model)

  // Bytes escritos en THR que todavía no han salido por stx, en el orden en que se escribieron
  bit [7:0] tx_expected[$];

  // Cuántos caracteres se compararon y cuántos no coincidieron
  int unsigned tx_checked;
  int unsigned tx_errors;

  function new(string name = "uart_serie_model");
    super.new(name);
  endfunction

  // Alguien escribió un byte en THR: el UART lo tiene que sacar por stx más adelante
  function void write_thr(bit [7:0] data);
    tx_expected.push_back(data);
  endfunction

  // El monitor de stx vio salir un carácter: tiene que ser el más viejo que se escribió en THR
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

endclass : uart_serie_model