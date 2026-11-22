// RAL generado con PeakRDL (uart_ral_pkg, uart_dl_ral_pkg): adaptador, predictor y entorno.
// Ref: V-REG-01, V-REG-02, V-REG-03, V-RST-01. Dueño: Eric.
//
// Solape de direcciones: con DLAB = LCR[7] = 1, las direcciones 0 y 1 son DLL y DLM
// (bloque uart_dl_regs); con DLAB = 0 son RBR/THR e IER (bloque uart_regs).
// El resto de direcciones es igual con cualquier DLAB y vive en uart_regs.
`ifndef UART_RAL_ENV_SV
`define UART_RAL_ENV_SV

// ---------------------------------------------------------------------------
// Adaptador: uvm_reg_bus_op <-> wishB_item
// En 32 bits el RTL es big endian (LITLE_ENDIAN sin definir, uart_wb.v:293-298):
// dirección N[1:0] = 0, 1, 2, 3 -> sel = 1000, 0100, 0010, 0001.
// Los registros de 32 bits (Debug 1 y 2) usan sel = 1111.
// ---------------------------------------------------------------------------
class uart_ral_adapter extends uvm_reg_adapter;
  `uvm_object_utils(uart_ral_adapter)

  function new(string name = "uart_ral_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0; // el driver escribe el dato leído en el mismo item
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    wishB_item it = wishB_item::type_id::create("it");
    int k = 3 - rw.addr[1:0];
    it.we        = (rw.kind == UVM_WRITE);
    it.adr       = rw.addr;
    it.delay     = 0;
    it.stb_delay = 0;
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

// ---------------------------------------------------------------------------
// Predictor: un solo predictor para los dos bloques. Elige el mapa según el DLAB
// del espejo antes de predecir cada transacción del monitor.
// ---------------------------------------------------------------------------
class uart_ral_predictor extends uvm_reg_predictor #(wishB_item);
  `uvm_component_utils(uart_ral_predictor)

  uart_ral_pkg::uart_regs       regs;
  uart_dl_ral_pkg::uart_dl_regs dl_regs;

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

    // Con DLAB = 1 el RTL no aplica los efectos de lectura de LSR y MSR
    // (uart_regs.v:439-441). Se copia el valor leído sin limpiar los bits RC.
    if (dlab && rw.kind == UVM_READ && rw.addr inside {5, 6}) begin
      rg = map.get_reg_by_offset(rw.addr, 1);
      if (rg != null)
        void'(rg.predict(rw.data, -1, UVM_PREDICT_DIRECT, UVM_FRONTDOOR, map));
      reg_ap.write(tr);
      return;
    end

    super.write(tr);
  endfunction
endclass : uart_ral_predictor

// ---------------------------------------------------------------------------
// Entorno del RAL: crea los dos bloques, el adaptador y el predictor.
// El entorno padre llama a connect_bus() en su connect_phase con el agente Wishbone.
// ---------------------------------------------------------------------------
class uart_ral_env extends uvm_env;
  `uvm_component_utils(uart_ral_env)

  uart_ral_pkg::uart_regs       regs;     // DLAB = 0 y registros comunes
  uart_dl_ral_pkg::uart_dl_regs dl_regs;  // DLAB = 1: DLL y DLM
  uart_ral_adapter              adapter;
  uart_ral_predictor            predictor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // La prueba puede pasar los bloques ya creados; si no, se crean aquí.
    if (!uvm_config_db#(uart_ral_pkg::uart_regs)::get(this, "", "uart_regs", regs)) begin
      regs = new("regs"); // PeakRDL no registra las clases en la fábrica
      regs.build();
      regs.lock_model();
    end
    if (!uvm_config_db#(uart_dl_ral_pkg::uart_dl_regs)::get(this, "", "uart_dl_regs", dl_regs)) begin
      dl_regs = new("dl_regs");
      dl_regs.build();
      dl_regs.lock_model();
    end

    // Para secuencias, scoreboard y monitores que leen el espejo (LCR, DL, IER).
    uvm_config_db#(uart_ral_pkg::uart_regs)::set(null, "*", "uart_regs", regs);
    uvm_config_db#(uart_dl_ral_pkg::uart_dl_regs)::set(null, "*", "uart_dl_regs", dl_regs);

    adapter   = uart_ral_adapter::type_id::create("adapter");
    predictor = uart_ral_predictor::type_id::create("predictor", this);
  endfunction

  // Predicción explícita: el espejo solo cambia con lo que ve el monitor.
  function void connect_bus(wishB_sequencer sqr, uvm_analysis_port #(wishB_item) ap);
    if (sqr != null) begin
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

  // Escribe el divisor sin tocar THR/IER: sube DLAB, escribe DLL y DLM y restaura LCR.
  task write_dl(input bit [15:0] dl, output uvm_status_e status, input uvm_sequence_base parent = null);
    uvm_reg_data_t lcr = regs.LCR.get_mirrored_value();
    regs.LCR.write(status, lcr | 8'h80, .parent(parent));
    dl_regs.DLL.write(status, dl[7:0],  .parent(parent));
    dl_regs.DLM.write(status, dl[15:8], .parent(parent));
    regs.LCR.write(status, lcr, .parent(parent));
  endtask
endclass : uart_ral_env

`endif
