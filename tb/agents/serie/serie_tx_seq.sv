// Secuencia TX: escribe una ráfaga de bytes en THR para que el UART los transmita por stx.
// Corre sobre el secuenciador Wishbone y escribe por medio del modelo de registros.
class serie_tx_seq extends uvm_sequence #(wishB_item);
  `uvm_object_utils(serie_tx_seq)

// La configuración y el modelo de registros se los asigna quien arranca la secuencia
  config_serie            cfg;
  dlab0_rm_pkg::dlab0_rm  regs;

  function new(string name = "serie_tx_seq");
    super.new(name);
  endfunction

  task body();
    int unsigned n_bytes;
    bit [7:0]    data;
    uvm_status_e status;

    if (cfg == null || regs == null)
      `uvm_fatal("CFG", "serie_tx_seq necesita cfg y regs antes de arrancar")

    // Cuántos bytes trae la ráfaga casi siempre pocos, de vez en cuando muchos
    if (!std::randomize(n_bytes) with {
          n_bytes dist { [1 : cfg.tx_payload_max]                          :/ 100 - cfg.tx_payload_tail_pct,
                         [cfg.tx_payload_max + 1 : cfg.tx_payload_abs_max] :/ cfg.tx_payload_tail_pct };
        })
      `uvm_fatal("CFG", "serie_tx_seq no pudo sortear el largo de la ráfaga")

    // Se escriben seguidos, sin esperar a que la FIFO tenga espacio, con esto probamos llenarla
    repeat (n_bytes) begin
      data = $urandom_range(0, 255);
      regs.THR.write(status, data, .parent(this));
      if (status != UVM_IS_OK)
        `uvm_error("SER", $sformatf("No se pudo escribir 0x%02h en THR", data))
    end
  endtask

endclass : serie_tx_seq