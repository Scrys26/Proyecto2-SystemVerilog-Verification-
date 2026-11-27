
class uart_main_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(uart_main_vseq)
  `uvm_declare_p_sequencer(uart_virtual_sequencer)

  virtual wishB_if wb_vif;
  virtual int_if irq_vif;
  virtual serie_if ser_vif;

  uart_env_cfg cfg;
  uart_ral_env ral;
  uart_modem_irq_cov cov;

  int unsigned service_mode;
  bit traffic_done;
  semaphore bus_guard;

  function new(string name = "uart_main_vseq");
    super.new(name);
    bus_guard = new(1);
  endfunction

  task body();
    uvm_reg_hw_reset_seq reset_seq;
    bit [7:0] lcr;
    bit [7:0] fcr;
    bit [7:0] ier;
    bit [7:0] mcr;
    int unsigned total_weight;
    int unsigned choice;

    if (p_sequencer == null || p_sequencer.cfg == null ||
        p_sequencer.ral == null || p_sequencer.wb_sqr == null ||
        p_sequencer.ser_sqr == null || p_sequencer.modem_sqr == null)
      `uvm_fatal("MAIN_VSEQ", "Faltan secuenciadores, cfg o RAL")

    cfg = p_sequencer.cfg;
    ral = p_sequencer.ral;
    cfg.check_cfg();

    if (!uvm_config_db#(virtual wishB_if)::get(
          p_sequencer, "", "vif", wb_vif))
      `uvm_fatal("MAIN_VSEQ", "No se encontro wishB_if")

    if (!uvm_config_db#(virtual int_if)::get(
          p_sequencer, "", "vif", irq_vif))
      `uvm_fatal("MAIN_VSEQ", "No se encontro int_if")

    if (!uvm_config_db#(virtual serie_if)::get(
          p_sequencer, "", "vif", ser_vif))
      `uvm_fatal("MAIN_VSEQ", "No se encontro serie_if")

    // El reset a mitad de trafico necesita cambios en tb_top.
    if (cfg.rst_en != 0)
      `uvm_fatal("MAIN_VSEQ", "UART_RST_EN=1 aun no esta soportado")

    // Estas pruebas RAL quedan para otro paso.
    if (cfg.reg_bitbash_en || cfg.reg_access_en)
      `uvm_fatal("MAIN_VSEQ", "Pruebas RAL bitbash/access pendientes")

    if (!cfg.ser_cfg.randomize())
      `uvm_fatal("MAIN_VSEQ", "No se pudo aleatorizar config_serie")

    total_weight = cfg.sw_mode_weights[0] +
                   cfg.sw_mode_weights[1] + cfg.sw_mode_weights[2];

    if (total_weight == 0)
      `uvm_fatal("MAIN_VSEQ", "Los pesos del modo de servicio son cero")

    choice = $urandom_range(total_weight - 1, 0);

    if (choice < cfg.sw_mode_weights[0])
      service_mode = 0;
    else if (choice < cfg.sw_mode_weights[0] + cfg.sw_mode_weights[1])
      service_mode = 1;
    else
      service_mode = 2;

    if (cov != null)
      cov.set_service_mode(service_mode[1:0]);

    `uvm_info("MAIN_VSEQ", $sformatf(
      "Modo=%0d DL=%0d LCR=%02h TL=%0d",
      service_mode, cfg.ser_cfg.dl,
      cfg.ser_cfg.get_lcr(), cfg.ser_cfg.fifo_trigger), UVM_LOW)

    // Revisamos primero los registros despues del reset.
    reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
    reset_seq.model = ral.regs;
    reset_seq.start(p_sequencer.wb_sqr, this);

    // Configuramos el UART antes del trafico.
    lcr = cfg.ser_cfg.get_lcr();
    write_reg(ral.regs.LCR, lcr);

    // Escribimos DLM antes de DLL y bloqueamos Wishbone.
    begin
      uvm_status_e st;

      p_sequencer.wb_sqr.lock(this);
      ral.write_dl(cfg.ser_cfg.dl, st, this);
      p_sequencer.wb_sqr.unlock(this);

      if (st != UVM_IS_OK)
        `uvm_fatal("MAIN_VSEQ", "No se pudo configurar el divisor")
    end

    fcr = {cfg.ser_cfg.fifo_trigger, 3'b000, 3'b111};
    write_reg(ral.regs.FCR, fcr);

    ier = 8'h00;
    mcr = 8'h00;

    for (int i = 0; i < 4; i++) begin
      ier[i] = ($urandom_range(99, 0) < cfg.modem_cfg.ier_weights[i]);
      mcr[i] = ($urandom_range(99, 0) < cfg.modem_cfg.mcr_weights[i]);
    end

    mcr[4] = ($urandom_range(99, 0) <
              cfg.modem_cfg.mcr_loopback_pct);

    write_reg(ral.regs.IER, ier);
    write_reg(ral.regs.MCR, mcr);

    traffic_done = 0;

    fork
      begin
        fork
          tx_thread();
          rx_thread();
          modem_thread();
          reconfig_thread();
        join

        traffic_done = 1;
      end

      service_thread();
    join

    // Quitamos break para que la linea pueda volver a 1.
    if (lcr[6])
      write_reg(ral.regs.LCR, lcr & 8'hBF);

    close_uart();

    `uvm_info("MAIN_VSEQ",
      "Terminaron los hilos y el cierre del UART", UVM_LOW)
  endtask

  task write_reg(uvm_reg rg, uvm_reg_data_t value);
    uvm_status_e st;

    rg.write(st, value, .parent(this));

    if (st != UVM_IS_OK)
      `uvm_fatal("MAIN_VSEQ",
        $sformatf("Fallo escritura de %s", rg.get_name()))
  endtask

  task tx_thread();
    serie_tx_seq seq;

    seq = serie_tx_seq::type_id::create("tx_seq");
    seq.cfg = cfg.ser_cfg;
    seq.regs = ral.regs;

    seq.start(p_sequencer.wb_sqr);
  endtask

  task rx_thread();
    serie_rx_seq seq;

    seq = serie_rx_seq::type_id::create("rx_seq");
    seq.start(p_sequencer.ser_sqr);
  endtask

  task modem_thread();
    mod_seq seq;

    seq = mod_seq::type_id::create("modem_seq");
    seq.num_steps = cfg.modem_steps;

    seq.start(p_sequencer.modem_sqr);
  endtask

  task reconfig_thread();
    bit [7:0] data;

    repeat (cfg.reg_access_count) begin
      data = $urandom_range(255, 0);

      bus_guard.get(1);

      if ($urandom_range(99, 0) < cfg.reg_dlab_pct) begin
        // Bloqueamos el bus mientras cambiamos DLAB.
        p_sequencer.wb_sqr.lock(this);

        write_reg(ral.regs.LCR, cfg.ser_cfg.get_lcr() | 8'h80);
        write_reg(ral.regs.SCR, data);
        write_reg(ral.regs.LCR, cfg.ser_cfg.get_lcr());

        p_sequencer.wb_sqr.unlock(this);
      end
      else begin
        write_reg(ral.regs.SCR, data);
      end

      bus_guard.put(1);
    end
  endtask

  function int unsigned poll_cycles();

    if (cfg.sw_poll_max < 10000 &&
        $urandom_range(99, 0) < cfg.sw_poll_tail_pct)
      return $urandom_range(10000, cfg.sw_poll_max + 1);

    return $urandom_range(cfg.sw_poll_max, 0);
  endfunction

  task service_thread();
    int unsigned delay_cycles;

    while (!traffic_done) begin
      delay_cycles = poll_cycles();

      repeat (delay_cycles + 1) @(wb_vif.monitor_cb);

      if (traffic_done)
        break;

      if (service_mode == 0) begin
        service_poll();
      end
      else if (irq_vif.mon_cb.int_o === 1'b1) begin
        service_irq();
      end
      else if (service_mode == 2) begin
        service_poll();
      end
    end
  endtask

  task service_poll();
    uvm_status_e st;
    uvm_reg_data_t lsr;

    bus_guard.get(1);

    ral.regs.LSR.read(st, lsr, .parent(this));

    if (st != UVM_IS_OK)
      `uvm_error("MAIN_VSEQ", "Error al consultar LSR")

    if (lsr[0])
      drain_rx();

    ral.regs.MSR.read(st, lsr, .parent(this));

    if (st != UVM_IS_OK)
      `uvm_error("MAIN_VSEQ", "Error al consultar MSR")

    bus_guard.put(1);
  endtask

  task service_irq();
    uvm_status_e st;
    uvm_reg_data_t iir;
    int unsigned n_chars;
    longint unsigned delay_cycles;

    if ($urandom_range(99, 0) < cfg.sw_ignore_pct)
      return;

    if (cfg.sw_service_delay_max < 100 &&
        $urandom_range(99, 0) < cfg.sw_service_tail_pct)
      n_chars = $urandom_range(100, cfg.sw_service_delay_max + 1);
    else
      n_chars = $urandom_range(cfg.sw_service_delay_max, 0);

    // Esperamos la latencia medida en tiempos de caracter.
    delay_cycles = 16 * longint'(cfg.ser_cfg.dl) * 12 * n_chars;

    repeat (delay_cycles) @(wb_vif.monitor_cb);

    bus_guard.get(1);

    ral.regs.IIR.read(st, iir, .parent(this));

    if (st != UVM_IS_OK)
      `uvm_error("MAIN_VSEQ", "Error al leer IIR")

    case (iir[3:0])
      4'h6: begin
        uvm_reg_data_t lsr;
        ral.regs.LSR.read(st, lsr, .parent(this));
      end

      4'h4, 4'hC: drain_rx();

      4'h0: begin
        uvm_reg_data_t msr;
        ral.regs.MSR.read(st, msr, .parent(this));
      end

      4'h2: ; // Leer IIR atiende THRE.

      default: ;
    endcase

    bus_guard.put(1);
  endtask

  task close_uart();
    uvm_status_e st;
    uvm_reg_data_t lsr;
    int unsigned max_polls;

    if (cfg.ser_cfg.dl == 0) begin
      `uvm_info("MAIN_VSEQ",
        "DL=0: no se espera trafico serie", UVM_LOW)
      return;
    end

    max_polls = cfg.ser_cfg.tx_payload_abs_max * 12 + 64;

    for (int i = 0; i < max_polls; i++) begin
      ral.regs.LSR.read(st, lsr, .parent(this));

      if (st != UVM_IS_OK)
        `uvm_fatal("MAIN_VSEQ",
          "No se pudo consultar LSR al cerrar")

      if (lsr[0])
        drain_rx();

      if (irq_vif.mon_cb.int_o === 1'b1)
        service_irq();

      if (lsr[6:5] == 2'b11 &&
          ser_vif.mon_cb.stx === 1'b1 &&
          irq_vif.mon_cb.int_o === 1'b0) begin

        `uvm_info("MAIN_VSEQ",
          "TX vacio y linea en reposo", UVM_LOW)
        return;
      end

      repeat (16 * cfg.ser_cfg.dl) @(wb_vif.monitor_cb);
    end

    `uvm_warning("MAIN_VSEQ",
      "No se confirmo el cierre dentro del limite")
  endtask

  task drain_rx();
    uvm_status_e st;
    uvm_reg_data_t lsr;
    uvm_reg_data_t rx_data;

    repeat (cfg.sw_drain_max) begin
      ral.regs.LSR.read(st, lsr, .parent(this));

      if (st != UVM_IS_OK || !lsr[0])
        break;

      ral.regs.RBR.read(st, rx_data, .parent(this));

      if (st != UVM_IS_OK)
        `uvm_error("MAIN_VSEQ", "Error al leer RBR")
    end
  endtask

endclass : uart_main_vseq
