// Cobertura funcional independiente del DUT para V-MOD-01/02 y V-INT-01/02/03.
class uart_modem_irq_cov extends uvm_object;
  `uvm_object_utils(uart_modem_irq_cov)

  covergroup cg_modem with function sample(bit [3:0] pins, bit [3:0] deltas, bit lb);
    option.per_instance = 1;
    cp_pins: coverpoint pins {
      bins all_inactive = {4'hF};
      bins all_active   = {4'h0};
      bins mixed        = {[1:14]};
    }
    cp_delta: coverpoint deltas {
      bins none = {0};
      bins cts = {1}; bins dsr = {2}; bins ri = {4}; bins dcd = {8};
      bins multiple = {[3:15]} with ($countones(item) >= 2);
    }
    cp_loopback: coverpoint lb {bins normal = {0}; bins loopback = {1};}
    x_loopback_delta: cross cp_loopback, cp_delta;
  endgroup

  covergroup cg_interrupt with function sample(bit [3:0] code, bit [3:0] ier);
    option.per_instance = 1;
    cp_iir: coverpoint code {
      bins none = {4'h1}; bins rls = {4'h6}; bins rda = {4'h4};
      bins timeout = {4'hC}; bins thre = {4'h2}; bins modem = {4'h0};
      illegal_bins unexpected = default;
    }
    cp_ier: coverpoint ier {bins disabled = {0}; bins enabled[] = {[1:15]};}
    x_int_ier: cross cp_iir, cp_ier;
  endgroup

  function new(string name = "uart_modem_irq_cov");
    super.new(name);
    cg_modem = new();
    cg_interrupt = new();
  endfunction

  function void sample_modem(bit [3:0] pins, bit [3:0] delta, bit loopback);
    cg_modem.sample(pins, delta, loopback);
  endfunction

  function void sample_iir(bit [3:0] code, bit [3:0] ier);
    cg_interrupt.sample(code, ier);
  endfunction
endclass : uart_modem_irq_cov
