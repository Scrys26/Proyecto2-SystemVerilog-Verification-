class uart_int_model extends uvm_object;

  `uvm_object_utils(uart_int_model)

  // IER[0] = RX/timeout, IER[1] = THRE, IER[2] = errores, IER[3] = modem.
  local bit [3:0] ier;

  // Estas entradas deben venir de los modelos de referencia, NO de IIR/int_o.
  local bit [7:0] lsr_expected;
  local int unsigned rx_count_expected;
  local int unsigned rx_trigger_expected;
  local bit timeout_expected;
  local bit [3:0] msr_delta_expected;

  function new(string name = "uart_int_model");
    super.new(name);
    reset_model();
  endfunction

  function void reset_model();
    ier                 = 4'b0000;
    lsr_expected        = 8'h60;  // THRE y TEMT despues del reset
    rx_count_expected   = 0;
    rx_trigger_expected = 14;     // FCR[7:6] = 2'b11 al reset del RTL
    timeout_expected    = 0;
    msr_delta_expected  = 4'b0000;
  endfunction

  function void set_ier(input bit [3:0] value);
    ier = value;
  endfunction
  

  function void update_sources(
    input bit [7:0]     lsr_value,
    input int unsigned  rx_count,
    input int unsigned  rx_trigger,
    input bit           timeout_expired,
    input bit [3:0]     msr_deltas
  );
    if (!(rx_trigger inside {1, 4, 8, 14}))
      `uvm_fatal("IRQ_MODEL", "Nivel de disparo RX no valido")
       lsr_expected        = lsr_value;
       rx_count_expected   = rx_count;
       rx_trigger_expected = rx_trigger;
       timeout_expected    = timeout_expired;
       msr_delta_expected  = msr_deltas;
    endfunction 
    
    function bit [3:0] predict_iir();
        if (ier[2] && (|lsr_expected[4:1]))
            return 4'h6; 
        if (ier[0] && (rx_count_expected >= rx_trigger_expected))
            return 4'h4;
        if (ier[0] && (rx_count_expected > 0) && timeout_expected)
            return  4'hc;
        if (ier[1] && lsr_expected[5])
            return 4'h2;
        if(ier[3] && (|msr_delta_expected))
            return 4'h0;
        return  4'h1;
    endfunction 
    
    function bit [7:0] predict_iir_byte();
        return {4'hc, predict_iir()};
    endfunction 
    
    function bit has_enabled_cause(); 
        bit [3:0] iir_value;
        iir_value = predict_iir();
        return !iir_value[0];
    endfunction 
endclass : uart_int_model
