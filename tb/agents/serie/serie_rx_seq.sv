// Manda ráfaga de carácteres al dut por la línea serie, con la receta que ya viene armada en el item.
// También decide si la trama va buena o con error.

class serie_rx_seq extends uvm_sequence #(serie_item);
  `uvm_object_utils(serie_rx_seq) // incluye el factory y el create() de la clase
  `uvm_declare_p_sequencer(serie_sequencer) // puntero a serie_sequencer

  function new(string name = "serie_rx_seq");
    super.new(name);
  endfunction

  task body();
    config_serie cfg;
    int unsigned n_frames;
    bit [7:0]    lcr;
    bit [15:0]   dl;

    cfg = p_sequencer.cfg;

    // Cuántos caracteres trae la ráfaga, casi siempre pocos, de vez en cuando muchos
    if (!std::randomize(n_frames) with {
          n_frames dist { [1 : cfg.ser_payload_max]                           :/ 100 - cfg.ser_payload_tail_pct,
                          [cfg.ser_payload_max + 1 : cfg.ser_payload_abs_max] :/ cfg.ser_payload_tail_pct };
        })
      `uvm_fatal("CFG", "serie_rx_seq no pudo sortear el largo de la ráfaga")

    repeat (n_frames) begin
      req     = serie_item::type_id::create("req");
      req.cfg = cfg;
      start_item(req);
      if (!req.randomize())
        `uvm_fatal("CFG", "serie_rx_seq no pudo sortear el carácter")

      // El formato se lee justo antes de mandar, por si alguien reconfiguró el UART mientras tanto
      lcr      = p_sequencer.regmodel.lcr.get_mirrored_value();
      dl[15:8] = p_sequencer.regmodel.dlm.get_mirrored_value();
      dl[7:0]  = p_sequencer.regmodel.dll.get_mirrored_value();
      req.build_frame(lcr, dl);
      finish_item(req);
    end
  endtask

endclass : serie_rx_seq