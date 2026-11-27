
class uart_msr_model extends uvm_object;
  `uvm_object_utils(uart_msr_model)

  // pin_inputs[3:0] = {CTS, DSR, RI, DCD}
  local bit [3:0] pins;

  // MCR[4:0] = {LOOPBACK, OUT2, OUT1, RTS, DTR}
  local bit [4:0] mcr;

  // Estado interno del modelo de referencia.
  local bit [3:0] delayed_modem_signals;
  local bit [7:0] msr_expected;
  local bit       msi_reset;
  local bit       read_requested;

  function new(string name = "uart_msr_model");
    super.new(name);
    reset_model();
  endfunction

  function void reset_model();

    pins = 4'b1111;
    mcr = 5'b00000;

    delayed_modem_signals = 4'b0000;
    msr_expected = 8'h00;

    // Corresponde al reset de msi_reset en el RTL.
    msi_reset = 1'b1;
    read_requested = 1'b0;

  endfunction


  function void observe_pins(input bit [3:0] new_pins);

    pins = new_pins;

  endfunction
  function void set_mcr(input bit [4:0] value);

    mcr = value;

  endfunction
  function void on_msr_read();

    read_requested = 1'b1;

  endfunction

  function void tick(input bit read_msr = 1'b0);

    bit [3:0] current_active;
    bit [3:0] upper;
    bit [3:0] next_delta;
    bit effective_read;
    current_active = ~{
      pins[0],
      pins[1],
      pins[2],
      pins[3]
    };

    if (mcr[4]) begin

      upper = {
        mcr[3],
        mcr[2],
        mcr[0],
        mcr[1]
      };

    end
    else begin

      // Modo normal:
      // Bits altos del MSR segun los pines fisicos.
      upper = {
        pins[0],
        pins[1],
        pins[2],
        pins[3]
      };

    end
    if (msi_reset) begin

      next_delta = 4'b0000;

    end
    else begin

      next_delta =
        msr_expected[3:0] |
        (current_active ^ delayed_modem_signals);

    end
    effective_read = read_msr | read_requested;
    if (msi_reset) begin

      msi_reset = 1'b0;

    end
    else if (effective_read) begin

      msi_reset = 1'b1;

    end

    msr_expected = {
      upper,
      next_delta
    };

    delayed_modem_signals = current_active;

    // Consumir la solicitud de lectura.
    read_requested = 1'b0;

  endfunction

  function bit [7:0] predict_msr();

    return msr_expected;

  endfunction


  function bit [3:0] expected_delta();

    return msr_expected[3:0];

  endfunction

  function bit [3:0] current_pins();

    return pins;

  endfunction


  function bit in_loopback();

    return mcr[4];

  endfunction

  function bit expected_rts();

    return mcr[1];

  endfunction

  function bit expected_dtr();

    return mcr[0];

  endfunction

endclass : uart_msr_model
