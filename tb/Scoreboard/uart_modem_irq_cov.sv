
class uart_modem_irq_cov extends uvm_object;
  `uvm_object_utils(uart_modem_irq_cov)

  bit [3:0] last_pins;
  bit have_last_pins;
  bit [1:0] service_mode;
  bit have_service_mode;

  // En una muestra puede que no tengamos todos los datos.
  covergroup cg_modem with function sample(
    bit [3:0] pins,
    bit [3:0] delta,
    bit lb,
    int unsigned signal_id,
    bit changed,
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

    cp_delta: coverpoint delta {
      bins none = {4'h0};
      bins cts  = {4'h1};
      bins dsr  = {4'h2};
      bins ri   = {4'h4};
      bins dcd  = {4'h8};
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
      bins none    = {4'h1};
      bins rls     = {4'h6};
      bins rda     = {4'h4};
      bins timeout = {4'hC};
      bins thre    = {4'h2};
      bins modem   = {4'h0};
      illegal_bins invalid_id = default;
    }

    cp_ier: coverpoint ier {
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
      // Si IER deshabilita una causa, ese ID no puede aparecer.
      ignore_bins rls_disabled =
        binsof(cp_iir_id.rls) &&
        binsof(cp_ier) intersect {0, 1, 2, 3, 8, 9, 10, 11};

      ignore_bins rx_disabled =
        binsof(cp_iir_id.rda) &&
        binsof(cp_ier) intersect {0, 2, 4, 6, 8, 10, 12, 14};

      ignore_bins timeout_disabled =
        binsof(cp_iir_id.timeout) &&
        binsof(cp_ier) intersect {0, 2, 4, 6, 8, 10, 12, 14};

      ignore_bins thre_disabled =
        binsof(cp_iir_id.thre) &&
        binsof(cp_ier) intersect {0, 1, 4, 5, 8, 9, 12, 13};

      ignore_bins modem_disabled =
        binsof(cp_iir_id.modem) &&
        binsof(cp_ier) intersect {[0:7]};
    }

    x_int_ier: cross cp_int_o, cp_ier iff (has_int);
  endgroup

  function new(string name = "uart_modem_irq_cov");
    super.new(name);
    cg_modem = new();
    cg_int = new();
    reset_tracking();
  endfunction

  // Esto se llama al reset para no contar cambios falsos.
  function void reset_tracking();
    have_last_pins = 0;
    have_service_mode = 0;
  endfunction

  // Se usa con las muestras del monitor de modem.
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

    // Un evento puede cambiar varios pines al mismo tiempo.
    for (int i = 0; i < 4; i++) begin
      if (changed_pins[3-i]) begin
        cg_modem.sample(pins, delta, loopback,
                        i, 1'b1, 0, 0, 1'b0, 1'b1);
        found_change = 1;
      end
    end

    if (!found_change)
      cg_modem.sample(pins, delta, loopback,
                      0, 1'b0, 0, 0, 1'b0, 1'b1);

    last_pins = pins;
    have_last_pins = 1;
  endfunction

  // Solo se llama al recibir una lectura real de MSR.
  // mcr_out corresponde a MCR[3:0].
  function void sample_msr(
    bit [7:0] msr_observed,
    bit [3:0] mcr_out,
    bit loopback
  );
    cg_modem.sample(last_pins, msr_observed[3:0], loopback,
                    0, 1'b0, msr_observed[7:4], mcr_out,
                    1'b1, have_last_pins);
  endfunction

  // Se usa con las lecturas de IIR de Wishbone.
  function void sample_iir(bit [3:0] code, bit [3:0] ier);
    cg_int.sample(code, ier, 0, service_mode,
                  1'b1, 1'b0, have_service_mode);
  endfunction

  // Se usa al observar int_o, no al generar el estimulo.
  function void sample_int_o(bit observed, bit [3:0] ier);
    cg_int.sample(0, ier, observed, service_mode,
                  1'b0, 1'b1, have_service_mode);
  endfunction

  // Si tenemos IIR e int_o en la misma muestra.
  function void sample_iir_and_int(
    bit [3:0] code,
    bit [3:0] ier,
    bit observed
  );
    cg_int.sample(code, ier, observed, service_mode,
                  1'b1, 1'b1, have_service_mode);
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
  endfunction

endclass : uart_modem_irq_cov
