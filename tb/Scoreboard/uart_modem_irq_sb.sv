
`uvm_analysis_imp_decl(_modem)
`uvm_analysis_imp_decl(_wb_modem)
`uvm_analysis_imp_decl(_irq)

class uart_modem_irq_sb extends uvm_scoreboard;
  `uvm_component_utils(uart_modem_irq_sb)

  // Entradas de los monitores.
  uvm_analysis_imp_modem
    #(mod_pin_event, uart_modem_irq_sb) modem_in;

  uvm_analysis_imp_wb_modem
    #(wishB_item, uart_modem_irq_sb) wb_in;

  uvm_analysis_imp_irq
    #(bit, uart_modem_irq_sb) irq_in;

  // Interfaces publicas.
  virtual wishB_if wb_vif;
  virtual int_if   int_vif;

  // Modelos de referencia.
  uart_msr_model     msr_model;
  uart_int_model     irq_model;
  uart_modem_irq_cov cov;

  // Registros de configuracion esperados.
  bit [7:0] lcr_shadow;
  bit [3:0] ier_shadow;
  bit [1:0] fcr_tl;

  // Fuentes esperadas de interrupcion.
  logic [7:0]  next_lsr;
  int unsigned next_rx_count;
  logic        next_timeout;

  bit sources_ready;
  bit irq_history_ok;
  bit irq_prediction_valid;
  bit missing_sources_warned;

  // Seguimiento de la temporizacion Wishbone.
  bit wb_qualified_prev;
  bit [1:0] wb_state;
  bit wb_wre;

  bit [`UART_ADDR_WIDTH-1:0] wb_adr_prev;
  bit [`UART_DATA_WIDTH-1:0] wb_dat_prev;
  bit [3:0] wb_sel_prev;
  bit wb_we_prev;

  // Valores esperados capturados durante el acceso.
  bit iir_snapshot_present;
  bit iir_snapshot_valid;
  bit [7:0] iir_snapshot;

  bit msr_snapshot_present;
  bit [7:0] msr_snapshot;

  bit msr_clear_next;

  // Contadores de comprobaciones.
  int unsigned msr_reads;
  int unsigned msr_checks;
  int unsigned msr_errors;
  int unsigned msr_skipped;

  int unsigned iir_reads;
  int unsigned iir_checks;
  int unsigned iir_errors;
  int unsigned iir_skipped;

  int unsigned irq_cycles;
  int unsigned irq_events;
  int unsigned int_checks;
  int unsigned int_errors;

  function new(
    string name = "uart_modem_irq_sb",
    uvm_component parent = null
  );
    super.new(name, parent);

    modem_in = new("modem_in", this);
    wb_in    = new("wb_in", this);
    irq_in   = new("irq_in", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    msr_model =
      uart_msr_model::type_id::create("msr_model");

    irq_model =
      uart_int_model::type_id::create("irq_model");

    cov =
      uart_modem_irq_cov::type_id::create("cov");

    if (!uvm_config_db#(virtual wishB_if)::get(
          this, "", "vif", wb_vif))
      `uvm_fatal("MODEM_IRQ_SB",
        "No se encontro virtual wishB_if")

    if (!uvm_config_db#(virtual int_if)::get(
          this, "", "vif", int_vif))
      `uvm_fatal("MODEM_IRQ_SB",
        "No se encontro virtual int_if")
  endfunction

  // Restablecer los modelos ante reset del DUT.
  function void reset_models();

    msr_model.reset_model();
    irq_model.reset_model();

    lcr_shadow = 8'h03;
    ier_shadow = 4'h0;
    fcr_tl     = 2'b11;

    sources_ready = 0;
    irq_history_ok = 1;
    irq_prediction_valid = 0;
    missing_sources_warned = 0;

    wb_qualified_prev = 0;
    wb_state = 0;
    wb_wre = 1;

    wb_adr_prev = '0;
    wb_dat_prev = '0;
    wb_sel_prev = '0;
    wb_we_prev = 0;

    iir_snapshot_present = 0;
    iir_snapshot_valid = 0;
    msr_snapshot_present = 0;

    msr_clear_next = 0;

  endfunction

  // Convertir FCR[7:6] al nivel RX esperado.
  function int unsigned get_rx_trigger();

    case (fcr_tl)
      2'b00: return 1;
      2'b01: return 4;
      2'b10: return 8;
      2'b11: return 14;
    endcase

    return 14;
  endfunction

  // Recibir las fuentes esperadas de Diego.
  //
  // Se debe llamar una vez por ciclo, antes del
  // flanco positivo, desde un modelo independiente.
  function void provide_irq_sources(
    input logic [7:0]   lsr_expected,
    input int unsigned  rx_count_expected,
    input logic         timeout_expected
  );

    if (sources_ready) begin
      irq_history_ok = 0;
      irq_prediction_valid = 0;

      `uvm_error("IRQ_SOURCES",
        "Dos actualizaciones en un mismo ciclo")
    end

    next_lsr = lsr_expected;
    next_rx_count = rx_count_expected;
    next_timeout = timeout_expected;

    sources_ready = 1;
  endfunction

  // Decodificar direccion y byte Wishbone.
  function bit decode_byte(
    input bit [`UART_ADDR_WIDTH-1:0] addr_bus,
    input bit [3:0] sel,
    input bit [`UART_DATA_WIDTH-1:0] data_bus,
    output int unsigned addr,
    output bit [7:0] value
  );

    int lane;

    addr = 0;
    value = 0;

`ifdef DATA_BUS_WIDTH_8

    addr = int'(addr_bus);
    value = data_bus[7:0];

`else

    case (sel)
      4'b0001: lane = 0;
      4'b0010: lane = 1;
      4'b0100: lane = 2;
      4'b1000: lane = 3;
      default: return 0;
    endcase

`ifdef LITLE_ENDIAN
    addr = (int'(addr_bus) & ~3) | lane;
`else
    addr = (int'(addr_bus) & ~3) | (3 - lane);
`endif

    value = (data_bus >> (8 * lane)) & 8'hFF;

`endif

    return 1;

  endfunction

  // Aplicar escrituras al modelo de configuracion.
  //
  // Se llama despues de tick() porque el RTL
  // actualiza los registros con NBA.
  function void apply_register_write(
    input int unsigned addr,
    input bit [7:0] value
  );

    case (addr)

      // IER, si DLAB = 0.
      1: begin
        if (!lcr_shadow[7]) begin
          ier_shadow = value[3:0];
          irq_model.set_ier(ier_shadow);
        end
      end

      // FCR.
      2: begin
        fcr_tl = value[7:6];
      end

      // LCR.
      3: begin
        lcr_shadow = value;
      end

      // MCR.
      4: begin
        msr_model.set_mcr(value[4:0]);

        cov.sample_modem(
          msr_model.current_pins(),
          msr_model.expected_delta(),
          msr_model.in_loopback()
        );
      end

      default: ;

    endcase
  endfunction

  // Sincronizacion integrada en el scoreboard.
  task run_phase(uvm_phase phase);

    bit bus_access;
    bit bus_read_lsr;
    bit bus_read_iir;
    bit bus_read_rbr;
    bit bus_write_thr;
    bit bus_read_msr;

    bit [7:0] bus_value;
    int unsigned bus_addr;
    bit decode_ok;

    reset_models();

    forever begin

      @(wb_vif.monitor_cb);

      // Reset del UART.
      if (wb_vif.monitor_cb.rst !== 1'b0) begin
        reset_models();
        continue;
      end

      // Comprobar int_o del ciclo anterior.
      if (irq_prediction_valid) begin

        if ($isunknown(int_vif.mon_cb.int_o)) begin

          int_errors++;

          `uvm_error("INT_SB",
            "int_o contiene X/Z")

        end
        else begin

          int_checks++;

          if (int_vif.mon_cb.int_o !==
              irq_model.predict_int_o()) begin

            int_errors++;

            `uvm_error("INT_SB",
              $sformatf(
                "int_o observado=%0b esperado=%0b",
                int_vif.mon_cb.int_o,
                irq_model.predict_int_o()
              ))
          end

        end
      end

      // Identificar el acceso  al UART.
      // El adaptador Wishbone registra primero
      // las senales externas.
      bus_access =
        wb_qualified_prev && wb_wre;

      bus_addr = 0;
      bus_value = 0;
      decode_ok = 0;

      if (bus_access) begin

        decode_ok = decode_byte(
          wb_adr_prev,
          wb_sel_prev,
          wb_dat_prev,
          bus_addr,
          bus_value
        );

        iir_snapshot_present = 0;
        msr_snapshot_present = 0;

      end

      // Pulsos de acceso efectivos.
      bus_read_lsr =
        bus_access && decode_ok &&
        !wb_we_prev &&
        (bus_addr == 5) &&
        !lcr_shadow[7];

      bus_read_iir =
        bus_access && decode_ok &&
        !wb_we_prev &&
        (bus_addr == 2) &&
        !lcr_shadow[7];

      bus_read_rbr =
        bus_access && decode_ok &&
        !wb_we_prev &&
        (bus_addr == 0) &&
        !lcr_shadow[7];

      bus_write_thr =
        bus_access && decode_ok &&
        wb_we_prev &&
        (bus_addr == 0) &&
        !lcr_shadow[7];

      bus_read_msr =
        bus_access && decode_ok &&
        !wb_we_prev &&
        (bus_addr == 6) &&
        !lcr_shadow[7];

      // Capturar el valor esperado ANTES de
      // avanzar los registros del modelo.
      if (bus_access && decode_ok &&
          !wb_we_prev) begin

        // Lectura IIR.
        if (bus_addr == 2) begin

          iir_snapshot_present = 1;
          iir_snapshot_valid = irq_prediction_valid;
          iir_snapshot =irq_model.predict_iir_byte();

        end

        // Lectura MSR.
        if (bus_addr == 6) begin

          msr_snapshot_present = 1;

          msr_snapshot =
            msr_model.predict_msr();

        end

      end

      // Actualizar el modelo una vez por ciclo.
      if (irq_history_ok && sources_ready && !$isunknown({next_lsr, next_timeout})) begin

        irq_model.update_sources(next_lsr,next_rx_count, get_rx_trigger(),next_timeout,msr_model.expected_delta());

        irq_model.tick(bus_read_lsr,bus_read_iir,bus_read_rbr,bus_write_thr,bus_read_msr );
        irq_cycles++;
        irq_prediction_valid = 1;

      end
      else begin

        irq_history_ok = 0;
        irq_prediction_valid = 0;

        if (!missing_sources_warned) begin

          `uvm_warning("IRQ_SOURCES",
            "Faltan fuentes esperadas por ciclo; IIR e int_o no se compararan hasta el siguiente reset")

          missing_sources_warned = 1;

        end
      end
      sources_ready = 0;
      // Efecto de limpieza de MSR.
      if (msr_clear_next)
        msr_model.on_msr_read();

      msr_clear_next = bus_read_msr;

      // Aplicar escrituras despues de tick().
      if (bus_access &&
          decode_ok &&
          wb_we_prev) begin

        apply_register_write(
          bus_addr,
          bus_value
        );

      end
      // Seguimiento de la maquina de acceso
      // Wishbone, usando solamente pines externos.
      case (wb_state)

        2'd0: begin

          if (wb_qualified_prev) begin
            wb_state = 2'd1;
            wb_wre = 0;
          end
          else begin
            wb_state = 2'd0;
            wb_wre = 1;
          end

        end

        2'd1: begin
          wb_state = 2'd2;
          wb_wre = 0;
        end

        default: begin
          wb_state = 2'd0;
          wb_wre = 0;
        end

      endcase
      // Guardar controles para el proximo ciclo.
      wb_qualified_prev =
        wb_vif.monitor_cb.cyc &&
        wb_vif.monitor_cb.stb;

      wb_adr_prev =
        wb_vif.monitor_cb.adr;

      wb_dat_prev =
        wb_vif.monitor_cb.dat_m2s;

      wb_sel_prev =
        wb_vif.monitor_cb.sel;

      wb_we_prev =
        wb_vif.monitor_cb.we;

    end

  endtask
  // Eventos del monitor de modem.
  function void write_modem(mod_pin_event t);

    if ($isunknown(t.pin_inputs)) begin

      `uvm_warning("MODEM_SB",
        "Pines de modem con X/Z")

      return;
    end
    msr_model.observe_pins(t.pin_inputs);

    cov.sample_modem(
      t.pin_inputs,
      msr_model.expected_delta(),
      msr_model.in_loopback()
    );

  endfunction
  // Transacciones completadas Wishbone.
  function void write_wb_modem(wishB_item t);

    int unsigned addr;
    bit [7:0] observed;
    bit [7:0] expected;

    if (!decode_byte(
          t.adr,
          t.sel,
          t.dat,
          addr,
          observed))
      return;
    if (t.we)
      return;
    case (addr)

      // Comparar IIR.
      2: begin

        iir_reads++;

        cov.sample_iir(
          observed[3:0],
          ier_shadow
        );

        if (!iir_snapshot_present ||
            !iir_snapshot_valid) begin

          iir_skipped++;

        end
        else begin

          expected = iir_snapshot;
          iir_checks++;

          if (observed !== expected) begin

            iir_errors++;

            `uvm_error("IIR_SB",
              $sformatf(
                "IIR leido=%02h esperado=%02h IER=%01h",
                observed,
                expected,
                ier_shadow
              ))
          end
        end
        iir_snapshot_present = 0;

      end
      // Comparar MSR.
      6: begin

        msr_reads++;

        if (!msr_snapshot_present) begin

          msr_skipped++;
        end
        else begin

          expected = msr_snapshot;
          msr_checks++;

          if (observed !== expected) begin

            msr_errors++;

            `uvm_error("MSR_SB",
              $sformatf(
                "MSR leido=%02h esperado=%02h",
                observed,
                expected
              ))
          end

        end
        msr_snapshot_present = 0;
      end
      default: ;
    endcase

  endfunction

  function void write_irq(bit observed);

    irq_events++;

    `uvm_info("INT_MON_SB",
      $sformatf(
        "Cambio int_o observado=%0b",
        observed
      ),
      UVM_HIGH)

  endfunction

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("MODEM_IRQ_SB",
      $sformatf(
        "MSR: %0d lecturas, %0d checks, %0d errores, %0d omitidas | IIR: %0d lecturas, %0d checks, %0d errores, %0d omitidas | int_o: %0d checks, %0d errores | ciclos=%0d",
        msr_reads, msr_checks, msr_errors, msr_skipped,iir_reads,iir_checks, iir_errors, iir_skipped, int_checks, int_errors,irq_cycles
      ),
      UVM_LOW)

    if (iir_checks == 0)
      `uvm_warning("MODEM_IRQ_SB",
        "IIR sin comparaciones validas")

    if (int_checks == 0)
      `uvm_warning("MODEM_IRQ_SB",
        "int_o sin comparaciones validas")

    if (msr_checks == 0)
      `uvm_warning("MODEM_IRQ_SB",
        "MSR no se comprobo")

  endfunction

endclass : uart_modem_irq_sb
