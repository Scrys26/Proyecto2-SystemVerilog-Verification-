
class uart_env_cfg extends uvm_object;
  `uvm_object_utils(uart_env_cfg)

  // Configuraciones de los agentes.
  config_wishB wb_cfg;
  config_serie ser_cfg;
  config_mod   modem_cfg;

  // Valor inicial de la secuencia principal.
  // uart_base_test procesara el plusarg correspondiente.
  int unsigned modem_steps = 20;

  function new(string name = "uart_env_cfg");
    super.new(name);

    wb_cfg =
      config_wishB::type_id::create("wb_cfg");

    ser_cfg =
      config_serie::type_id::create("ser_cfg");

    modem_cfg =
      config_mod::type_id::create("modem_cfg");
  endfunction

  function void check_cfg();

    if (wb_cfg == null ||
        ser_cfg == null ||
        modem_cfg == null)
      `uvm_fatal("ENV_CFG",
        "Falta alguna configuracion de agente")

  endfunction

endclass : uart_env_cfg
