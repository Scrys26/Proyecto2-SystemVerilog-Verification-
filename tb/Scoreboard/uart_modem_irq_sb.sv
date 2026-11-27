
`uvm_analysis_imp_decl(_modem)
`uvm_analysis_imp_decl(_wb_modem)
`uvm_analysis_imp_decl(_irq)

class uart_modem_irq_sb extends uvm_scoreboard;
  `uvm_component_utils(uart_modem_irq_sb)

  uvm_analysis_imp_modem   #(mod_pin_event, uart_modem_irq_sb) modem_in;
  uvm_analysis_imp_wb_modem #(wishB_item, uart_modem_irq_sb)  wb_in;
  uvm_analysis_imp_irq     #(bit, uart_modem_irq_sb)         irq_in;

  uart_msr_model       msr_model;
  uart_int_model       irq_model;
  uart_modem_irq_cov   cov;
  bit [7:0] lcr_shadow = 8'h03;
  bit [3:0] ier_shadow;
  bit [1:0] fcr_tl = 2'b11;
  int unsigned msr_checks, msr_errors, iir_observations, irq_edges;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    modem_in = new("modem_in", this);
    wb_in    = new("wb_in", this);
    irq_in   = new("irq_in", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    msr_model = uart_msr_model::type_id::create("msr_model");
    irq_model = uart_int_model::type_id::create("irq_model");
    cov       = uart_modem_irq_cov::type_id::create("cov");
  endfunction

  function void write_modem(mod_pin_event t);
    if ($isunknown(t.pin_inputs)) begin
      `uvm_warning("MSR_SB", "Pins de modem contienen X/Z; evento descartado")
      return;
    end
    msr_model.observe_pins(t.pin_inputs);
    cov.sample_modem(t.pin_inputs, msr_model.expected_delta(), msr_model.in_loopback());
  endfunction

  // El bus de 8 bits ignora wb_sel_i y usa la direccion directamente.
  function bit decode_byte(wishB_item t, output int unsigned reg_adr,
                           output bit [7:0] b);
    int lane;
    if (`UART_DATA_WIDTH == 8) begin
      reg_adr = t.adr;
      b = t.dat[7:0];
      return 1;
    end
    case (t.sel)
      4'b0001: lane = 0;
      4'b0010: lane = 1;
      4'b0100: lane = 2;
      4'b1000: lane = 3;
      default: begin
        `uvm_warning("MSR_SB", $sformatf("sel no unitario: %04b; omitido", t.sel))
        return 0;
      end
    endcase
    reg_adr = (int'(t.adr) & ~3) | (3 - lane);
    b = (t.dat >> (8 * lane)) & 8'hFF;
    return 1;
  endfunction

  function void write_wb_modem(wishB_item t);
    int unsigned addr;
    bit [7:0] byte_value;
    bit [7:0] expected;
    if (!decode_byte(t, addr, byte_value)) return;

    if (t.we) begin
      case (addr)
        1: if (!lcr_shadow[7]) begin
          ier_shadow = byte_value[3:0];
          irq_model.set_ier(ier_shadow);
        end
        2: fcr_tl = byte_value[7:6];
        3: lcr_shadow = byte_value;
        4: begin
          msr_model.set_mcr(byte_value[4:0]);
          cov.sample_modem(msr_model.current_pins(), msr_model.expected_delta(), byte_value[4]);
        end
      endcase
      return;
    end

    case (addr)
      2: begin
        iir_observations++;
        cov.sample_iir(byte_value[3:0], ier_shadow);
      end
      6: begin
        // El RTL entrega los datos ANTES del efecto lateral de la lectura.
        expected = msr_model.predict_msr();
        msr_checks++;
        if (byte_value !== expected) begin
          msr_errors++;
          `uvm_error("MSR_SB", $sformatf("MSR leido=%02h esperado=%02h (WB)", byte_value, expected))
        end
        msr_model.on_msr_read();
      end
    endcase
  endfunction

  function void write_irq(bit sampled);
    irq_edges++;
    `uvm_info("IRQ_SB", $sformatf("int_o observado=%0b; comparacion temporal aun no habilitada", sampled), UVM_HIGH)
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("MODEM_SB", $sformatf("MSR: %0d comparaciones, %0d errores. IIR: %0d lecturas observadas. IRQ: %0d eventos.",
                  msr_checks, msr_errors, iir_observations, irq_edges), UVM_LOW)
    if (msr_checks == 0)
      `uvm_warning("MODEM_SB", "No hubo lecturas de MSR; no se ejercito su comparacion")
  endfunction
endclass : uart_modem_irq_sb
