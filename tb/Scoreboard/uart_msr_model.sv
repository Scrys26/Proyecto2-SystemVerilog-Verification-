
class uart_msr_model extends uvm_object;
  `uvm_object_utils(uart_msr_model)

  local bit [3:0] pins;
  local bit [4:0] mcr;
  local bit [3:0] previous_active;
  local bit [3:0] delta;

  function new(string name = "uart_msr_model");
    super.new(name);
    reset_model();
  endfunction

  function void reset_model();
    pins = 4'b1111;
    mcr = 5'b0;
    previous_active = 4'b0000;  // delayed_modem_signals al reset del RTL.
    delta = 4'b0;
  endfunction

  function void set_mcr(input bit [4:0] value);
    mcr = value;
  endfunction

  function void observe_pins(input bit [3:0] new_pins);
    bit [3:0] current_active;
    // Orden bit[3:0] = {DCD, RI, DSR, CTS}.
    current_active = ~{new_pins[0], new_pins[1], new_pins[2], new_pins[3]};
    delta |= (current_active ^ previous_active);
    previous_active = current_active;
    pins = new_pins;
  endfunction

  function bit in_loopback();
    return mcr[4];
  endfunction

  function bit [3:0] current_pins();
    return pins;
  endfunction

  function bit [3:0] expected_delta();
    return delta;
  endfunction

  function bit [7:0] predict_msr();
    bit [3:0] upper;
    if (mcr[4])
      // En loopback: CTS<-RTS, DSR<-DTR, RI<-OUT1, DCD<-OUT2.
      upper = {mcr[3], mcr[2], mcr[0], mcr[1]};
    else
      upper = {pins[0], pins[1], pins[2], pins[3]};
    return {upper, delta};
  endfunction

  function void on_msr_read();
    delta = 4'b0;
  endfunction
endclass : uart_msr_model
