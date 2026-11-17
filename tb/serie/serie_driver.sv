// Pone en srx la trama que ya viene armada en el item.
class serie_driver extends uvm_driver #(serie_item);
  `uvm_component_utils(serie_driver) // incluye el factory y el create() de la clase

  virtual serie_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

// Primero busca la conexión si no la encuentra tira error
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual serie_if)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "serie_driver no encontró la interfaz serie_if en uvm_config_db")
  endfunction

// Pide un carácter, copia su receta al cable segmento por segmento, avisa que terminó, y vuelve a empezar.
  task run_phase(uvm_phase phase);
    // La línea arranca en 1, porque si queda en 0 o en X el UART lo toma como un bit de inicio
    vif.drv_cb.srx <= 1'b1;
    forever begin
      seq_item_port.get_next_item(req);
      `uvm_info("SER", $sformatf("Enviando por srx: %s", req.convert2string()), UVM_HIGH)
      foreach (req.seg_level[i]) begin
        vif.drv_cb.srx <= req.seg_level[i];
        repeat (req.seg_clks[i]) @(vif.drv_cb);
      end
      seq_item_port.item_done();
    end
  endtask

endclass : serie_driver