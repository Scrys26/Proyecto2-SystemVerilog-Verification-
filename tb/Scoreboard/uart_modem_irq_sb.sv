
`uvm_analysis_imp_decl(_modem)
`uvm_analysis_imp_decl(_wb_modem)
`uvm_analysis_imp_decl(_irq)

class uart_modem_irq_sb extends uvm_scoreboard;
  `uvm_component_utils(uart_modem_irq_sb)

  uvm_analysis_imp_modem #(mod_pin_event, uart_modem_irq_sb) modem_in;
  uvm_analysis_imp_wb_modem #(wishB_item, uart_modem_irq_sb) wb_in;
  uvm_analysis_imp_irq #(bit, uart_modem_irq_sb) irq_in;

  virtual wishB_if wb_vif;
  virtual mod_if   mod_vif;
  virtual int_if   int_vif;

  uart_msr_model msr_model;
  uart_int_model irq_model;
  uart_modem_irq_cov cov;

  bit [7:0] lcr_shadow;
  bit [3:0] ier_shadow;
  bit [4:0] mcr_shadow;
  bit [1:0] fcr_tl;

  logic [7:0] next_lsr;
  int unsigned next_rx_count;
  logic next_timeout;

  bit sources_ready;
  bit irq_history_ok;
  bit irq_prediction_valid;
  bit warned_sources;

  bit wb_qualified_prev;
  bit lsr_read_prev;
  bit [1:0] wb_state;
  bit wb_wre;

  bit [`UART_ADDR_WIDTH-1:0] wb_adr_prev;
  bit [`UART_DATA_WIDTH-1:0] wb_dat_prev;
  bit [3:0] wb_sel_prev;
  bit wb_we_prev;

  // Guardamos la lectura esperada hasta recibir el ACK.
  typedef struct packed {
    bit [7:0] addr;
    bit [7:0] expected;
    bit valid;
    bit [3:0] ier_at_read;
    bit [3:0] mcr_out_at_read;
    bit loopback_at_read;
  } read_info_t;

  read_info_t read_fifo[$];

  bit msr_valid;
  bit warned_pins;
  bit have_cov;

  bit [3:0] last_cov_pins;
  bit [3:0] last_cov_delta;
  bit last_cov_loopback;

  int unsigned modem_events;
  int unsigned irq_events;
  int unsigned irq_cycles;

  int unsigned msr_reads, msr_checks, msr_errors, msr_skipped;
  int unsigned iir_reads, iir_checks, iir_errors, iir_skipped;
  int unsigned int_checks, int_errors;

  function new(
    string name = "uart_modem_irq_sb",
    uvm_component parent = null
  );
    super.new(name, parent);

    modem_in = new("modem_in", this);
    wb_in = new("wb_in", this);
    irq_in = new("irq_in", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    msr_model = uart_msr_model::type_id::create("msr_model");
    irq_model = uart_int_model::type_id::create("irq_model");
    cov = uart_modem_irq_cov::type_id::create("cov");

    if (!uvm_config_db#(virtual wishB_if)::get(
          this, "", "vif", wb_vif))
      `uvm_fatal("MODEM_SB", "No se encontro wishB_if")

    if (!uvm_config_db#(virtual mod_if)::get(
          this, "", "vif", mod_vif))
      `uvm_fatal("MODEM_SB", "No se encontro mod_if")

    if (!uvm_config_db#(virtual int_if)::get(
          this, "", "vif", int_vif))
      `uvm_fatal("MODEM_SB", "No se encontro int_if")
  endfunction

  function void reset_models();
    msr_model.reset_model();
    irq_model.reset_model();

    lcr_shadow = 8'h03;
    ier_shadow = 4'h0;
    mcr_shadow = 5'h00;
    fcr_tl = 2'b11;

    cov.reset_tracking();

    sources_ready = 0;
    irq_history_ok = 1;
    irq_prediction_valid = 0;
    warned_sources = 0;

    wb_qualified_prev = 0;
    lsr_read_prev = 0;
    wb_state = 0;
    wb_wre = 1;

    wb_adr_prev = '0;
    wb_dat_prev = '0;
    wb_sel_prev = '0;
    wb_we_prev = 0;

    read_fifo.delete();

    msr_valid = 1;
    warned_pins = 0;
    have_cov = 0;
  endfunction

  function int unsigned get_rx_trigger();
    case (fcr_tl)
      2'b00: return 1;
      2'b01: return 4;
      2'b10: return 8;
      2'b11: return 14;
    endcase

    return 14;
  endfunction

  // Diego debe enviar estas fuentes antes de cada ciclo.
  function void provide_irq_sources(
    input logic [7:0] lsr_expected,
    input int unsigned rx_count_expected,
    input logic timeout_expected
  );
    if (sources_ready) begin
      irq_history_ok = 0;
      irq_prediction_valid = 0;

      `uvm_error("IRQ_SB",
        "Fuentes repetidas en el mismo ciclo")
    end

    next_lsr = lsr_expected;
    next_rx_count = rx_count_expected;
    next_timeout = timeout_expected;

    sources_ready = 1;
  endfunction

  // Obtenemos el byte del registro segun el bus.
  function bit decode_byte(
    input bit [`UART_ADDR_WIDTH-1:0] bus_addr,
    input bit [3:0] sel,
    input bit [`UART_DATA_WIDTH-1:0] data,
    output int unsigned reg_addr,
    output bit [7:0] value
  );
    int lane;

    reg_addr = 0;
    value = 0;

`ifdef DATA_BUS_WIDTH_8

    reg_addr = int'(bus_addr);
    value = data[7:0];

`else

    case (sel)
      4'b0001: lane = 0;
      4'b0010: lane = 1;
      4'b0100: lane = 2;
      4'b1000: lane = 3;
      default: return 0;
    endcase

`ifdef LITLE_ENDIAN
    reg_addr = (int'(bus_addr) & ~3) | lane;
`else
    reg_addr = (int'(bus_addr) & ~3) | (3 - lane);
`endif

    value = (data >> (8 * lane)) & 8'hFF;

`endif

    return 1;
  endfunction

  // Actualizamos los registros esperados.
  function void apply_write(
    input int unsigned addr,
    input bit [7:0] value
  );
    case (addr)

      1: begin
        if (!lcr_shadow[7]) begin
          ier_shadow = value[3:0];
          irq_model.set_ier(ier_shadow);

          // Tomamos cobertura con el nuevo valor de IER.
          if (!$isunknown(int_vif.mon_cb.int_o))
            cov.sample_int_o(
              bit'(int_vif.mon_cb.int_o),
              ier_shadow
            );
        end
      end

      2: begin
        fcr_tl = value[7:6];
      end

      3: begin
        lcr_shadow = value;
      end

      4: begin
        mcr_shadow = value[4:0];
        msr_model.set_mcr(mcr_shadow);
      end

      default: ;

    endcase
  endfunction

  task run_phase(uvm_phase phase);
    bit access_now;
    bit decoded;

    bit read_lsr;
    bit read_iir;
    bit read_rbr;
    bit write_thr;
    bit read_msr;

    int unsigned addr;
    bit [7:0] value;
    bit [3:0] pins;
    bit [3:0] delta;
    bit lb;

    read_info_t rd;

    reset_models();

    forever begin
      @(wb_vif.monitor_cb);

      if (wb_vif.monitor_cb.rst !== 1'b0) begin
        reset_models();
        continue;
      end

      // Revisamos int_o con el valor del ciclo anterior.
      if (irq_prediction_valid) begin
        int_checks++;

        if ($isunknown(int_vif.mon_cb.int_o) ||
            int_vif.mon_cb.int_o !==
              irq_model.predict_int_o()) begin

          int_errors++;

          `uvm_error("INT_SB",
            $sformatf(
              "int_o=%b esperado=%b",
              int_vif.mon_cb.int_o,
              irq_model.predict_int_o()
            ))
        end
      end

      // Leemos los pines del modem.
      if ($isunknown({
          mod_vif.mon_cb.cts,
          mod_vif.mon_cb.dsr,
          mod_vif.mon_cb.ri,
          mod_vif.mon_cb.dcd
        })) begin

        msr_valid = 0;
        irq_history_ok = 0;
        irq_prediction_valid = 0;

        if (!warned_pins) begin
          `uvm_warning("MODEM_SB",
            "Pines con X/Z; revisar desde reset")
          warned_pins = 1;
        end
      end
      else begin
        pins = {
          mod_vif.mon_cb.cts,
          mod_vif.mon_cb.dsr,
          mod_vif.mon_cb.ri,
          mod_vif.mon_cb.dcd
        };

        msr_model.observe_pins(pins);
      end

      // Identificamos el acceso Wishbone.
      access_now = wb_qualified_prev && wb_wre;

      decoded = 0;
      addr = 0;
      value = 0;

      if (access_now) begin
        decoded = decode_byte(
          wb_adr_prev,
          wb_sel_prev,
          wb_dat_prev,
          addr,
          value
        );
      end

      read_lsr =
        access_now && decoded &&
        !wb_we_prev &&
        addr == 5 &&
        !lcr_shadow[7];

      read_iir =
        access_now && decoded &&
        !wb_we_prev &&
        addr == 2 &&
        !lcr_shadow[7];

      read_rbr =
        access_now && decoded &&
        !wb_we_prev &&
        addr == 0 &&
        !lcr_shadow[7];

      write_thr =
        access_now && decoded &&
        wb_we_prev &&
        addr == 0 &&
        !lcr_shadow[7];

      read_msr =
        access_now && decoded &&
        !wb_we_prev &&
        addr == 6 &&
        !lcr_shadow[7];

      if (read_lsr && lsr_read_prev)
        read_lsr = 0;

      lsr_read_prev =
        access_now && decoded &&
        !wb_we_prev &&
        addr == 5 &&
        !lcr_shadow[7];

      // Guardamos el esperado y la configuracion de la lectura.
      if (access_now && decoded && !wb_we_prev) begin
        rd.addr = addr[7:0];
        rd.expected = 8'h00;
        rd.valid = 0;

        rd.ier_at_read = ier_shadow;
        rd.mcr_out_at_read = mcr_shadow[3:0];
        rd.loopback_at_read = mcr_shadow[4];

        if (addr == 2) begin
          rd.expected = irq_model.predict_iir_byte();
          rd.valid = irq_prediction_valid;
        end

        if (addr == 6) begin
          rd.expected = msr_model.predict_msr();
          rd.valid = msr_valid;
        end

        read_fifo.push_back(rd);
      end

      // Actualizamos las causas de interrupcion.
      if (irq_history_ok &&
          sources_ready &&
          msr_valid &&
          !$isunknown({next_lsr, next_timeout})) begin

        irq_model.update_sources(
          next_lsr,
          next_rx_count,
          get_rx_trigger(),
          next_timeout,
          msr_model.expected_delta()
        );

        irq_model.tick(
          read_lsr,
          read_iir,
          read_rbr,
          write_thr,
          read_msr
        );

        irq_cycles++;
        irq_prediction_valid = 1;
      end
      else begin
        irq_history_ok = 0;
        irq_prediction_valid = 0;

        if (!warned_sources) begin
          `uvm_warning("IRQ_SB",
            "Sin fuentes por ciclo; IIR e int_o quedan sin comprobar")
          warned_sources = 1;
        end
      end

      sources_ready = 0;

      // MSR sigue funcionando aunque falte el modelo serie.
      if (msr_valid)
        msr_model.tick(read_msr);

      if (access_now && decoded && wb_we_prev)
        apply_write(addr, value);

      // Guardamos cobertura cuando cambian los valores.
      if (msr_valid) begin
        delta = msr_model.expected_delta();
        lb = msr_model.in_loopback();

        if (!have_cov ||
            pins != last_cov_pins ||
            delta != last_cov_delta ||
            lb != last_cov_loopback) begin

          cov.sample_modem(pins, delta, lb);

          last_cov_pins = pins;
          last_cov_delta = delta;
          last_cov_loopback = lb;
          have_cov = 1;
        end
      end

      // Seguimos los ciclos del adaptador Wishbone.
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

      wb_qualified_prev =
        wb_vif.monitor_cb.cyc &&
        wb_vif.monitor_cb.stb;

      wb_adr_prev = wb_vif.monitor_cb.adr;
      wb_dat_prev = wb_vif.monitor_cb.dat_m2s;
      wb_sel_prev = wb_vif.monitor_cb.sel;
      wb_we_prev = wb_vif.monitor_cb.we;
    end
  endtask

  // Contamos los eventos que manda el monitor de modem.
  function void write_modem(mod_pin_event t);
    modem_events++;

    if ($isunknown(t.pin_inputs))
      `uvm_warning("MODEM_SB",
        "Evento de modem con X/Z")
  endfunction

  // Revisamos las lecturas que confirma Wishbone.
  function void write_wb_modem(wishB_item t);
    int unsigned addr;
    bit [7:0] value;
    read_info_t rd;

    if (t.we)
      return;

    if (!decode_byte(
          t.adr,
          t.sel,
          t.dat,
          addr,
          value)) begin

      `uvm_warning("MODEM_SB",
        "No se pudo decodificar la lectura")
      return;
    end

    if (addr == 2)
      iir_reads++;

    if (addr == 6)
      msr_reads++;

    if (read_fifo.size() == 0) begin
      if (addr == 2)
        iir_skipped++;

      if (addr == 6)
        msr_skipped++;

      `uvm_warning("MODEM_SB",
        "Llego ACK sin lectura esperada")
      return;
    end

    rd = read_fifo.pop_front();

    if (rd.addr != addr[7:0]) begin
      if (addr == 2)
        iir_skipped++;

      if (addr == 6)
        msr_skipped++;

      `uvm_error("MODEM_SB",
        $sformatf(
          "Lectura fuera de orden: esperada=%0d recibida=%0d",
          rd.addr,
          addr
        ))
      return;
    end

    if (addr == 2) begin

      // Esta muestra usa IER del momento de la lectura.
      cov.sample_iir(value[3:0], rd.ier_at_read);

      if (!rd.valid) begin
        iir_skipped++;
      end
      else begin
        iir_checks++;

        if (value !== rd.expected) begin
          iir_errors++;

          `uvm_error("IIR_SB",
            $sformatf(
              "IIR leido=%02h esperado=%02h",
              value,
              rd.expected
            ))
        end
      end
    end

    if (addr == 6) begin

      // Tomamos cobertura con el MSR leido.
      cov.sample_msr(
        value,
        rd.mcr_out_at_read,
        rd.loopback_at_read
      );

      if (!rd.valid) begin
        msr_skipped++;
      end
      else begin
        msr_checks++;

        if (value !== rd.expected) begin
          msr_errors++;

          `uvm_error("MSR_SB",
            $sformatf(
              "MSR leido=%02h esperado=%02h",
              value,
              rd.expected
            ))
        end
      end
    end
  endfunction

  // El monitor avisa cuando cambia int_o.
  function void write_irq(bit observed);
    irq_events++;

    cov.sample_int_o(observed, ier_shadow);

    `uvm_info("IRQ_SB",
      $sformatf("Cambio int_o=%0b", observed),
      UVM_HIGH)
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("MODEM_IRQ_SB",
      $sformatf(
        "MSR: %0d/%0d checks, errores=%0d, omitidas=%0d | IIR: %0d/%0d checks, errores=%0d, omitidas=%0d | int_o: checks=%0d, errores=%0d | eventos modem=%0d, irq=%0d",
        msr_checks,
        msr_reads,
        msr_errors,
        msr_skipped,
        iir_checks,
        iir_reads,
        iir_errors,
        iir_skipped,
        int_checks,
        int_errors,
        modem_events,
        irq_events
      ),
      UVM_LOW)

    if (msr_checks == 0)
      `uvm_warning("MODEM_IRQ_SB",
        "MSR no se comprobo")

    if (iir_checks == 0)
      `uvm_warning("MODEM_IRQ_SB",
        "IIR no se comprobo")

    if (int_checks == 0)
      `uvm_warning("MODEM_IRQ_SB",
        "int_o no se comprobo")
  endfunction

endclass : uart_modem_irq_sb
