class uart_modem_irq_cov extends uvm_object;
  `uvm_object_utils(uart_modem_irq_cov)

  // El orden de los pines es CTS, DSR, RI, DCD.
  bit [3:0] last_pins;
  bit have_last_pins;
  bit [1:0] service_mode;
  bit have_service_mode;

  // Estos contadores ayudan a revisar la prueba en el log.
  int unsigned pin_changes[4];
  int unsigned msr_samples;
  int unsigned iir_samples;
  int unsigned irq_samples;
  int unsigned mode_samples;

  covergroup cg_modem with function sample(
    bit [3:0] pins,
    bit [3:0] delta,
    bit lb,
    int unsigned signal_id,
    bit changed,
    bit direction_up,
    bit [3:0] msr_state,
    bit [3:0] mcr_out,
    bit msr_read,
    bit pins_valid
  );
    option.per_instance = 1;

    cp_pins: coverpoint pins iff (pins_valid) {
      bins all_low = {4'h0};
      bins all_high = {4'hF};
      bins mixed = {[1:14]};
    }

    cp_signal: coverpoint signal_id iff (changed) {
      bins cts = {0};
      bins dsr = {1};
      bins ri  = {2};
      bins dcd = {3};
    }

    // 0 significa bajada y 1 significa subida.
    cp_direction: coverpoint direction_up iff (changed) {
      bins falling = {0};
      bins rising = {1};
    }

    cp_delta: coverpoint delta {
      bins none = {4'h0};
      bins cts = {4'h1};
      bins dsr = {4'h2};
      bins ri = {4'h4};
      bins dcd = {4'h8};
      bins multiple = {[0:15]} with ($countones(item) >= 2);
    }

    cp_msr_state: coverpoint msr_state iff (msr_read) {
      bins states[] = {[0:15]};
    }

    cp_mcr_out: coverpoint mcr_out iff (msr_read) {
      bins values[] = {[0:15]};
    }

    cp_lb_en: coverpoint lb {
      bins normal = {0};
      bins loopback = {1};
    }

    x_delta_signal: cross cp_delta, cp_signal iff (changed);
    x_signal_direction: cross cp_signal, cp_direction iff (changed);
    x_lb_mcr_out: cross cp_lb_en, cp_mcr_out iff (msr_read);
  endgroup

  covergroup cg_int with function sample(
    bit [3:0] iir_id,
    bit [3:0] ier,
    bit int_o,
    bit [1:0] mode,
    bit has_iir,
    bit has_int,
    bit has_mode
  );
    option.per_instance = 1;

    cp_iir_id: coverpoint iir_id iff (has_iir) {
      bins none = {4'h1};
      bins rls = {4'h6};
      bins rda = {4'h4};
      bins timeout = {4'hC};
      bins thre = {4'h2};
      bins modem = {4'h0};
      illegal_bins invalid_id = default;
    }

    // No contar un IER inventado al muestrear solo el modo.
    cp_ier: coverpoint ier iff (has_iir || has_int) {
      bins values[] = {[0:15]};
    }

    cp_int_o: coverpoint int_o iff (has_int) {
      bins low = {0};
      bins high = {1};
    }

    cp_mode: coverpoint mode iff (has_mode) {
      bins polling = {0};
      bins interrupts = {1};
      bins mixed = {2};
    }

    x_iir_ier: cross cp_iir_id, cp_ier iff (has_iir) {
      ignore_bins rls_disabled =
        binsof(cp_iir_id.rls) &&
        binsof(cp_ier) intersect {0,1,2,3,8,9,10,11};
      ignore_bins rx_disabled =
        binsof(cp_iir_id.rda) &&
        binsof(cp_ier) intersect {0,2,4,6,8,10,12,14};
      ignore_bins timeout_disabled =
        binsof(cp_iir_id.timeout) &&
        binsof(cp_ier) intersect {0,2,4,6,8,10,12,14};
      ignore_bins thre_disabled =
        binsof(cp_iir_id.thre) &&
        binsof(cp_ier) intersect {0,1,4,5,8,9,12,13};
      ignore_bins modem_disabled =
        binsof(cp_iir_id.modem) &&
        binsof(cp_ier) intersect {[0:7]};
    }

    x_int_ier: cross cp_int_o, cp_ier iff (has_int) {
      // Sin bits IER habilitados no puede subir int_o.
      ignore_bins high_ier_zero =
        binsof(cp_int_o.high) &&
        binsof(cp_ier) intersect {0};
    }
  endgroup

  function new(string name = "uart_modem_irq_cov");
    super.new(name);
    cg_modem = new();
    cg_int = new();
    reset_tracking();
  endfunction

  // El historial se limpia durante reset. Los contadores son acumulados.
  function void reset_tracking();
    have_last_pins = 0;
    have_service_mode = 0;
  endfunction

  // Esta funcion se usa con los pines que observa el scoreboard.
  function void sample_modem(
    bit [3:0] pins,
    bit [3:0] delta,
    bit loopback
  );
    bit [3:0] changed_pins;
    bit found_change;

    changed_pins = 0;
    found_change = 0;

    if (have_last_pins)
      changed_pins = last_pins ^ pins;

    // Una muestra puede cambiar varios pines a la vez.
    for (int i = 0; i < 4; i++) begin
      if (changed_pins[3-i]) begin
        cg_modem.sample(pins, delta, loopback,
                        i, 1'b1, pins[3-i], 0, 0, 1'b0, 1'b1);
        pin_changes[i]++;
        found_change = 1;
      end
    end

    if (!found_change)
      cg_modem.sample(pins, delta, loopback,
                      0, 1'b0, 1'b0, 0, 0, 1'b0, 1'b1);

    last_pins = pins;
    have_last_pins = 1;
  endfunction

  // El MSR observado viene de una lectura real por Wishbone.
  function void sample_msr(
    bit [7:0] msr_observed,
    bit [3:0] mcr_out,
    bit loopback
  );
    cg_modem.sample(last_pins, msr_observed[3:0], loopback,
                    0, 1'b0, 1'b0, msr_observed[7:4], mcr_out,
                    1'b1, have_last_pins);
    msr_samples++;
  endfunction

  // El codigo IIR se obtiene de la lectura confirmada del DUT.
  function void sample_iir(bit [3:0] code, bit [3:0] ier);
    cg_int.sample(code, ier, 0, service_mode,
                  1'b1, 1'b0, have_service_mode);
    iir_samples++;
  endfunction

  // int_o se toma del monitor, no de la prediccion.
  function void sample_int_o(bit observed, bit [3:0] ier);
    cg_int.sample(0, ier, observed, service_mode,
                  1'b0, 1'b1, have_service_mode);
    irq_samples++;
  endfunction

  function void sample_iir_and_int(
    bit [3:0] code,
    bit [3:0] ier,
    bit observed
  );
    cg_int.sample(code, ier, observed, service_mode,
                  1'b1, 1'b1, have_service_mode);
    iir_samples++;
    irq_samples++;
  endfunction

  // 0 = polling, 1 = interrupciones, 2 = mixto.
  function void set_service_mode(bit [1:0] mode);
    if (mode > 2) begin
      `uvm_warning("MODEM_COV", "Modo de servicio invalido")
      have_service_mode = 0;
      return;
    end

    service_mode = mode;
    have_service_mode = 1;
    mode_samples++;

    // Guardamos el modo aunque no haya una interrupcion.
    cg_int.sample(0, 0, 0, service_mode,
                  1'b0, 1'b0, 1'b1);
  endfunction

  // Se puede llamar desde report_phase del scoreboard.
  function void report_coverage();
    `uvm_info("MODEM_COV", $sformatf(
      "Cobertura modem=%.1f%%, interrupciones=%.1f%% | cambios CTS=%0d DSR=%0d RI=%0d DCD=%0d | muestras MSR=%0d IIR=%0d int_o=%0d modo=%0d",
      cg_modem.get_inst_coverage(), cg_int.get_inst_coverage(),
      pin_changes[0], pin_changes[1], pin_changes[2], pin_changes[3],
      msr_samples, iir_samples, irq_samples, mode_samples
    ), UVM_LOW)
  endfunction

endclass : uart_modem_irq_cov
