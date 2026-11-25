// Monitor de la línea serie: escucha un cable y reconstruye cada carácter que pasa por él.
// Se usa dos veces en el agente, una para stx (lo que manda el DUT) y otra para srx (lo que le llega).

class serie_monitor extends uvm_monitor;
  `uvm_component_utils(serie_monitor)

  // Por aquí se publica cada carácter reconstruido para el scoreboard y la cobertura
  uvm_analysis_port #(serie_item) ap;

  virtual serie_if               vif;
  uart_ral_pkg::uart_regs        regs;
  uart_dl_ral_pkg::uart_dl_regs  dl_regs;

  // Cuál de los dos cables mira este monitor. Lo define el agente al crearlo.
  serie_dir_e dir = SER_DIR_RX;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  // Busca la interfaz y los registros; sin ellos no puede saber ni qué mirar ni cómo leerlo
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual serie_if)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "serie_monitor no encontró la interfaz serie_if en uvm_config_db")
    if (!uvm_config_db#(uart_ral_pkg::uart_regs)::get(this, "", "uart_regs", regs))
      `uvm_fatal("CFG", "serie_monitor no encontró el modelo de registros uart_regs")
    if (!uvm_config_db#(uart_dl_ral_pkg::uart_dl_regs)::get(this, "", "uart_dl_regs", dl_regs))
      `uvm_fatal("CFG", "serie_monitor no encontró el modelo de registros uart_dl_regs")
  endfunction

  // Espera que empiece una trama, lee bit por bit a la mitad de cada uno y publica lo que vio
  task run_phase(uvm_phase phase);
    serie_item   it;
    bit [7:0]    lcr;
    bit [15:0]   dl;
    int unsigned bit_clks;
    int unsigned nbits;
    bit          b;
    bit          p;
    bit          stop;
    bit          all_zero;

    forever begin
      // Una trama empieza cuando la línea está en reposo (1) y baja a 0
      wait_line(1'b1);
      wait_line(1'b0);

      // El formato se toma en este momento, por si alguien reconfiguró el UART entre tramas
      lcr      = regs.LCR.get_mirrored_value();
      dl[15:8] = dl_regs.DLM.get_mirrored_value();
      dl[7:0]  = dl_regs.DLL.get_mirrored_value();

      // Con DL en 0 el UART no transmite ni recibe, así que no hay nada que leer
      if (dl == 0) continue;

      bit_clks = 16 * dl;
      nbits    = lcr[1:0] + 5;

      // Se espera medio bit para quedar en el centro del bit de inicio.
      // Si ahí la línea ya volvió a 1 era un glitch, y el UART también lo descarta.
      repeat (bit_clks / 2) @(vif.mon_cb);
      if (line() != 1'b0) continue;

      it      = serie_item::type_id::create("it");
      it.dir  = dir;
      it.lcr  = lcr;
      it.dl   = dl;
      it.data = 8'h00;
      all_zero = 1'b1;

      // Desde el centro de un bit, un bit completo después cae en el centro del siguiente
      for (int i = 0; i < nbits; i++) begin
        repeat (bit_clks) @(vif.mon_cb);
        b = line();
        it.data[i] = b;
        if (b) all_zero = 1'b0;
      end

      // Paridad, solo si está activada en el LCR
      if (lcr[3]) begin
        repeat (bit_clks) @(vif.mon_cb);
        p = line();
        if (p) all_zero = 1'b0;
        it.pe = (p != serie_item::calc_parity(lcr, it.data, nbits));
      end

      // Solo se revisa el primer bit de parada, igual que el UART
      repeat (bit_clks) @(vif.mon_cb);
      stop  = line();
      it.fe = (stop == 1'b0);

      // Si todo vino en 0, incluido el bit de parada, es un break y no un carácter
      if (all_zero && stop == 1'b0) begin
        it.bi = 1'b1;
        it.pe = 1'b0;
        it.fe = 1'b0;
      end

      `uvm_info("SER", $sformatf("Carácter observado: %s", it.convert2string()), UVM_HIGH)
      ap.write(it);
    end
  endtask

  // Lee el cable que le toca a este monitor
  function bit line();
    if (dir == SER_DIR_TX)
      return vif.mon_cb.stx;
    return vif.mon_cb.srx;
  endfunction

  // Espera ciclo a ciclo hasta que la línea tenga el valor pedido
  task wait_line(bit value);
    while (line() !== value)
      @(vif.mon_cb);
  endtask

endclass : serie_monitor