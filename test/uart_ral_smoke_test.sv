// Prueba de humo del RAL sobre el agente Wishbone, fuera de la regresión de uart_base_test.
// Ref: V-RST-01, V-REG-01, V-REG-03. Dueño: Eric.
class uart_ral_smoke_test extends uvm_test;
  `uvm_component_utils(uart_ral_smoke_test)

  // Evita una simulación sin fin si una secuencia integrada se queda esperando.
  localparam time SMOKE_TIMEOUT = 1ms;

  config_wishB cfg;
  wishB_agent  wishB_agt;
  uart_ral_env ral_env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_top.set_timeout(SMOKE_TIMEOUT);

    cfg = config_wishB::type_id::create("cfg");
    cfg.parse_plusargs();
    // Se imprime antes de validar para que la traza quede en el log aunque check_knobs() corte.
    cfg.print_knobs();
    cfg.check_knobs();
    uvm_config_db#(config_wishB)::set(this, "wishB_agt*", "config_wishB", cfg);

    wishB_agt = wishB_agent::type_id::create("wishB_agt", this);
    ral_env   = uart_ral_env::type_id::create("ral_env", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ral_env.connect_bus(wishB_agt.sqr, wishB_agt.wishB_ap);
  endfunction

  task run_phase(uvm_phase phase);
    uart_ral_smoke_seq seq = uart_ral_smoke_seq::type_id::create("seq");
    seq.ral = ral_env;

    phase.raise_objection(this);
    seq.start(wishB_agt.sqr);
    phase.drop_objection(this);
  endtask

endclass : uart_ral_smoke_test
