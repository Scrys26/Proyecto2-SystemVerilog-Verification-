`ifndef UART_RAL_SVH
`define UART_RAL_SVH

class uart_reg extends uvm_reg;
  `uvm_object_utils(uart_reg)

  function new(string name = "uart_reg", int unsigned n_bits = 8);
    super.new(name, n_bits, UVM_NO_COVERAGE);
  endfunction

  function uvm_reg_field fld
    (
        string name, int unsigned size, int unsigned lsb,
        string acc, uvm_reg_data_t rst = 0
    );
    bit vol = acc inside {"RO", "RC"};
    fld = uvm_reg_field::type_id::create(name);
    fld.configure(this, size, lsb, acc, vol, rst, 1, 0, 0);
  endfunction
endclass

class uart_reg_block extends uvm_reg_block;
  `uvm_object_utils(uart_reg_block)

  uart_reg RBR, THR, IER, IIR, FCR, LCR, MCR, LSR, MSR, SCR, DLL, DLM, DBG1, DBG2;
  uvm_reg_field dlab;
  uvm_reg_map   dlab_map;

  function new(string name = "uart_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  function uart_reg mk(string name, string path = "", int unsigned n_bits = 8);
    mk = new(name, n_bits);
    mk.configure(this, null, path);
  endfunction

  function void both(uart_reg rg, uvm_reg_addr_t off, string acc = "RW");
    default_map.add_reg(rg, off, acc);
    dlab_map.add_reg(rg, off, acc);
  endfunction

  virtual function void build();
    RBR = mk("RBR");
    void'(RBR.fld("data", 8, 0, "RO"));
    THR = mk("THR");
    void'(THR.fld("data", 8, 0, "WO"));

    DLL = mk("DLL");
    void'(DLL.fld("dl_lsb", 8, 0, "RW"));
    DLL.add_hdl_path_slice("dl", 0, 8);

    DLM = mk("DLM");
    void'(DLM.fld("dl_msb", 8, 0, "RW"));
    DLM.add_hdl_path_slice("dl", 8, 8);

    IER = mk("IER", "ier");
    void'(IER.fld("en", 4, 0, "RW"));

    IIR = mk("IIR", "iir");
    void'(IIR.fld("int_pending", 1, 0, "RO", 1));
    void'(IIR.fld("int_id",      3, 1, "RO"));
    void'(IIR.fld("fifo_en",     4, 4, "RO", 'hC));

    FCR = mk("FCR");
    void'(FCR.fld("fifo_rst",   2, 1, "WO"));
    void'(FCR.fld("rx_trigger", 2, 6, "WO", 3));

    LCR = mk("LCR", "lcr");
    void'(LCR.fld("wls", 2, 0, "RW", 3));
    void'(LCR.fld("cfg", 5, 2, "RW"));
    dlab = LCR.fld("dlab", 1, 7, "RW");

    MCR = mk("MCR", "mcr");
    void'(MCR.fld("ctrl", 5, 0, "WO"));

    LSR = mk("LSR", "lsr");
    void'(LSR.fld("dr",        1, 0, "RO"));
    void'(LSR.fld("err",       4, 1, "RC"));
    void'(LSR.fld("thre_temt", 2, 5, "RO", 3));
    void'(LSR.fld("fifo_err",  1, 7, "RC"));

    MSR = mk("MSR", "msr");
    void'(MSR.fld("delta",  4, 0, "RC"));
    void'(MSR.fld("status", 4, 4, "RO"));

    SCR = mk("SCR", "scratch");
    void'(SCR.fld("scratch", 8, 0, "RW"));

    add_hdl_path("tb_top.dut.regs");

    default_map = create_map("map",      0, 4, UVM_LITTLE_ENDIAN, 1);
    dlab_map    = create_map("dlab_map", 0, 4, UVM_LITTLE_ENDIAN, 1);

    default_map.add_reg(RBR, 0, "RO");
    default_map.add_reg(THR, 0, "WO");
    default_map.add_reg(IER, 1);
    dlab_map.add_reg(DLL, 0);
    dlab_map.add_reg(DLM, 1);

    both(IIR, 2, "RO");
    both(FCR, 2, "WO");
    both(LCR, 3);
    both(MCR, 4, "WO");
    both(LSR, 5, "RO");
    both(MSR, 6, "RO");
    both(SCR, 7);

    `ifndef DATA_BUS_WIDTH_8
        DBG1 = mk("DBG1", "", 32);
        void'(DBG1.fld("data", 32, 0, "RO"));
        DBG2 = mk("DBG2", "", 32);
        void'(DBG2.fld("data", 32, 0, "RO"));
        both(DBG1, 8,  "RO");
        both(DBG2, 12, "RO");
    `endif

    lock_model();
  endfunction
endclass

class uart_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(uart_reg_adapter)

  function new(string name = "uart_reg_adapter");
    super.new(name);
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
      rw.addr = it.adr;
      rw.data = it.dat;
    end else begin
      rw.addr = (it.adr & ~3) | (3 - k);
      rw.data = (it.dat >> 8*k) & 'hFF;
    end
  endfunction
endclass

class uart_predictor extends uvm_reg_predictor #(wishB_item);
  `uvm_component_utils(uart_predictor)
  uart_reg_block rm;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void write(wishB_item tr);
    map = rm.dlab.get_mirrored_value() ? rm.dlab_map : rm.default_map;
    super.write(tr);
  endfunction
endclass

`endif