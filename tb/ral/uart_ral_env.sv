// RAL generado con PeakRDL (dlab0_rm_pkg, dlab1_rm_pkg): adaptador, predictor y entorno.
// Ref: V-REG-01, V-REG-02, V-REG-03, V-RST-01. Dueño: Eric.
//
// Solape de direcciones: con DLAB = LCR[7] = 1, las direcciones 0 y 1 son DLL y DLM
// (bloque dlab1_rm); con DLAB = 0 son RBR/THR e IER (bloque dlab0_rm)
// El resto de direcciones es igual con cualquier DLAB y vive en dlab0_rm
`ifndef UART_RAL_ENV_SV
`define UART_RAL_ENV_SV


class uart_ral_adapter extends uvm_reg_adapter;
  `uvm_object_utils(uart_ral_adapter)

  // Lo asigna uart_ral_env::connect_bus() desde el secuenciador Wishbone.
  config_wishB cfg;

  function new(string name = "uart_ral_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0; // el driver escribe el dato leído en el mismo item
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    wishB_item it = wishB_item::type_id::create("it");
    int k = 3 - rw.addr[1:0];

    // Mismos knobs que el resto del tráfico Wishbone; stb_delay >= WB_STB_DELAY_MIN evita AMB-05.
    if (cfg == null)
      `uvm_fatal("ADAPT", "uart_ral_adapter sin config_wishB: falta llamar a connect_bus()")
    if (!it.randomize() with {
          delay dist { [0 : cfg.wb_delay_max]                        :/ (100 - cfg.wb_delay_tail_pct),
                       [cfg.wb_delay_max + 1 : cfg.wb_delay_abs_max] :/ cfg.wb_delay_tail_pct };
          stb_delay inside {[cfg.wb_stb_delay_min : cfg.wb_stb_delay_max]};
        })
      `uvm_fatal("ADAPT", "No se pudieron aleatorizar los retardos del wishB_item")

    it.we  = (rw.kind == UVM_WRITE);
    it.adr = rw.addr;
    if (`UART_DATA_WIDTH == 8) begin
      it.sel = 4'b0001;
      it.dat = rw.data;
    end else if (rw.n_bits == 32) begin
      it.sel = 4'b1111;
      it.dat = rw.data;
    end else begin
      it.sel = 4'b0001 << k;
      it.dat = rw.data[7:0] << 8*k;
    end
    return it;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    wishB_item it;
    int k;
    if (!$cast(it, bus_item)) `uvm_fatal("ADAPT", "bus_item no es wishB_item")
    k         = $clog2(it.sel);
    rw.kind   = it.we ? UVM_WRITE : UVM_READ;
    rw.status = it.status;
    if (`UART_DATA_WIDTH == 8 || it.sel == 4'b1111) begin
      rw.addr   = it.adr;
      rw.data   = it.dat;
      rw.n_bits = (`UART_DATA_WIDTH == 8) ? 8 : 32;
    end else begin
      rw.addr   = (it.adr & ~3) | (3 - k);
      rw.data   = (it.dat >> 8*k) & 'hFF;
      rw.n_bits = 8;
    end
  endfunction
endclass : uart_ral_adapter

// Predictor un solo predictor para los dos bloques. Elige el mapa según el DLAB
// del espejo antes de predecir cada transacción del monitor.
class uart_ral_predictor extends uvm_reg_predictor #(wishB_item);
  `uvm_component_utils(uart_ral_predictor)

  dlab0_rm_pkg::dlab0_rm regs;
  dlab1_rm_pkg::dlab1_rm dl_regs;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void write(wishB_item tr);
    uvm_reg_bus_op rw;
    uvm_reg        rg;
    bit            dlab = regs.LCR.dlab.get_mirrored_value();

    rw.byte_en = '1;
    adapter.bus2reg(tr, rw);

    // Direcciones 0 y 1: el DLAB decide el bloque.
    map = (dlab && rw.addr inside {0, 1}) ? dl_regs.default_map : regs.default_map;

    // Con DLAB = 1 el RTL no aplica los efectos de lectura de LSR y MSR del spec
    // Se copia el valor leído sin limpiar los bits RC.
    if (dlab && rw.kind == UVM_READ && rw.addr inside {5, 6}) begin
      rg = map.get_reg_by_offset(rw.addr, 1);
      if (rg != null) begin
        // reg_ap publica uvm_reg_item (no wishB_item), igual que uvm_reg_predictor::write.
        uvm_reg_item reg_item = uvm_reg_item::type_id::create("reg_item");
        void'(rg.predict(rw.data, -1, UVM_PREDICT_DIRECT, UVM_FRONTDOOR, map));
        reg_item.element      = rg;
        reg_item.element_kind = UVM_REG;
        reg_item.kind         = rw.kind;
        reg_item.value[0]     = rw.data;
        reg_item.path         = UVM_FRONTDOOR;
        reg_item.map          = map;
        reg_item.status       = rw.status;
        reg_ap.write(reg_item);
      end
      return;
    end

    super.write(tr);
  endfunction
endclass : uart_ral_predictor

// Entorno del RAL: crea los dos bloques, el adaptador y el predictor.
// El entorno padre llama a connect_bus() en su connect_phase con el agente Wishbone.
class uart_ral_env extends uvm_env;
  `uvm_component_utils(uart_ral_env)

  dlab0_rm_pkg::dlab0_rm regs;     // DLAB = 0 y registros comunes
  dlab1_rm_pkg::dlab1_rm dl_regs;  // DLAB = 1: DLL y DLM
  uart_ral_adapter       adapter;
  uart_ral_predictor     predictor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // La prueba puede pasar los bloques ya creados; si no, se crean aquí.
    if (!uvm_config_db#(dlab0_rm_pkg::dlab0_rm)::get(this, "", "dlab0_rm", regs)) begin
      regs = dlab0_rm_pkg::dlab0_rm::type_id::create("regs");
      regs.build();
      add_backdoor_regs();
      regs.lock_model();
    end
    if (!uvm_config_db#(dlab1_rm_pkg::dlab1_rm)::get(this, "", "dlab1_rm", dl_regs)) begin
      dl_regs = dlab1_rm_pkg::dlab1_rm::type_id::create("dl_regs");
      dl_regs.build();
      add_backdoor_dl();
      dl_regs.lock_model();
    end

    // Para secuencias, scoreboard y monitores que leen el espejo (LCR, DL, IER).
    uvm_config_db#(dlab0_rm_pkg::dlab0_rm)::set(null, "*", "dlab0_rm", regs);
    uvm_config_db#(dlab1_rm_pkg::dlab1_rm)::set(null, "*", "dlab1_rm", dl_regs);

    adapter   = uart_ral_adapter::type_id::create("adapter");
    predictor = uart_ral_predictor::type_id::create("predictor", this);
  endfunction

  // Puerta trasera: PeakRDL no genera las rutas. Van antes de lock_model(), que congela el modelo.
  // Ruta completa = raíz del bloque + nombre del slice: tb_top.dut.regs.lcr (uart_top.v:268: instancia regs).
  // add_hdl_path_slice(señal, bit del registro donde empieza, ancho).
  local function void add_backdoor_regs();
    regs.add_hdl_path("tb_top.dut.regs");
    regs.IER.add_hdl_path_slice("ier",     0, 4);  // reg [3:0] ier (uart_regs.v:303); bits 7:4 leen 0
    regs.IIR.add_hdl_path_slice("iir",     0, 4);  // bits 7:4 son la constante 4'b1100 (uart_regs.v:410)
    regs.FCR.add_hdl_path_slice("fcr",     6, 2);  // el RTL solo guarda rx_trigger (uart_regs.v:305)
    regs.LCR.add_hdl_path_slice("lcr",     0, 8);
    regs.MCR.add_hdl_path_slice("mcr",     0, 5);
    regs.LSR.add_hdl_path_slice("lsr",     0, 8);  // wire (uart_regs.v:339): se lee, no se escribe
    regs.MSR.add_hdl_path_slice("msr",     0, 8);
    regs.SCR.add_hdl_path_slice("scratch", 0, 8);
  endfunction

  // DLL y DLM son las dos mitades de un solo vector reg [15:0] dl (uart_regs.v:309).
  local function void add_backdoor_dl();
    dl_regs.add_hdl_path("tb_top.dut.regs");
    dl_regs.DLL.add_hdl_path_slice("dl[7:0]",  0, 8);
    dl_regs.DLM.add_hdl_path_slice("dl[15:8]", 0, 8);
  endfunction

  // Predicción explícita: el espejo solo cambia con lo que ve el monitor.
  function void connect_bus(wishB_sequencer sqr, uvm_analysis_port #(wishB_item) ap);
    if (sqr != null) begin
      adapter.cfg = sqr.cfg;
      regs.default_map.set_sequencer(sqr, adapter);
      dl_regs.default_map.set_sequencer(sqr, adapter);
    end
    regs.default_map.set_auto_predict(0);
    dl_regs.default_map.set_auto_predict(0);

    predictor.regs    = regs;
    predictor.dl_regs = dl_regs;
    predictor.map     = regs.default_map;
    predictor.adapter = adapter;
    ap.connect(predictor.bus_in);
  endfunction

  // Reset de hardware: vuelve los espejos a los valores de reset.
  function void reset_model();
    regs.reset();
    dl_regs.reset();
  endfunction

  // Escribe el divisor sin tocar THR/IER: sube DLAB, escribe DLM y DLL y restaura LCR.
  // DLM primero porque escribir DLL arranca el contador del divisor.
  // La secuencia que lo llama hace lock() del secuenciador para que nadie se intercale.
  task write_dl(input bit [15:0] dl, output uvm_status_e status, input uvm_sequence_base parent = null);
    uvm_reg_data_t lcr = regs.LCR.get_mirrored_value();
    regs.LCR.write(status, lcr | 8'h80, .parent(parent));
    dl_regs.DLM.write(status, dl[15:8], .parent(parent));
    dl_regs.DLL.write(status, dl[7:0],  .parent(parent));
    regs.LCR.write(status, lcr, .parent(parent));
  endtask
endclass : uart_ral_env

`endif
