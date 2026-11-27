
class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_env_cfg cfg;

  wishB_agent wb_agt;
  serie_agent serie_agt;
  mod_agent   modem_agt;
  int_monitor irq_mon;

  uart_ral_env            ral;
  uart_modem_irq_sb       modem_irq_sb;
  uart_virtual_sequencer v_sqr;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(uart_env_cfg)::get(this, "", "uart_env_cfg", cfg))
      `uvm_fatal("UART_ENV", "uart_base_test no publico uart_env_cfg")

    cfg.check_cfg();

    // Publicar los objetos ANTES de crear los agentes.
    uvm_config_db#(config_wishB)::set(
      this, "wb_agt*", "config_wishB", cfg.wb_cfg);
    uvm_config_db#(config_serie)::set(
      this, "serie_agt*", "config_serie", cfg.ser_cfg);
    uvm_config_db#(config_mod)::set(
      this, "modem_agt*", "config_mod", cfg.modem_cfg);

    // El RAL se crea primero: publica dlab0_rm/dlab1_rm para serie.
    ral = uart_ral_env::type_id::create("ral", this);

    wb_agt    = wishB_agent::type_id::create("wb_agt", this);
    serie_agt = serie_agent::type_id::create("serie_agt", this);
    modem_agt = mod_agent::type_id::create("modem_agt", this);
    irq_mon   = int_monitor::type_id::create("irq_mon", this);

    modem_irq_sb = uart_modem_irq_sb::type_id::create("modem_irq_sb", this);
    v_sqr        = uart_virtual_sequencer::type_id::create("v_sqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

  
    if (wb_agt.sqr == null)
      `uvm_fatal("UART_ENV", "Wishbone debe ser activo para las secuencias RAL")

    ral.connect_bus(wb_agt.sqr, wb_agt.wishB_ap);

    // Secuenciador virtual
    v_sqr.wb_sqr    = wb_agt.sqr;
    v_sqr.ser_sqr   = serie_agt.sqr;
    v_sqr.modem_sqr = modem_agt.pin_seqr;
    v_sqr.ral       = ral;
    v_sqr.cfg       = cfg;

    // Monitor de modem -> scoreboard MSR / IRQ.
    modem_agt.pin_mon.mod_ap.connect(modem_irq_sb.modem_in);

    // Monitor Wishbone -> scoreboard y predictor RAL (fan-out).
    wb_agt.wishB_ap.connect(modem_irq_sb.wb_in);

    // Monitor de int_o -> scoreboard.
    irq_mon.int_ap.connect(modem_irq_sb.irq_in);

  endfunction
endclass : uart_env
