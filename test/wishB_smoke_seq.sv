// Accesos Wishbone crudos de la prueba de humo: lee LCR, IIR y LSR tras el reset y escribe y lee el scratch.
// Ref: V-WB-01, V-WB-02, V-RST-01. Dueño: Eric.
class wishB_smoke_seq extends uvm_sequence #(wishB_item);
  `uvm_object_utils(wishB_smoke_seq)
  `uvm_declare_p_sequencer(wishB_sequencer)

  bit [7:0]  scr_wdata = 8'hA5;
  bit [7:0]  lcr, iir, lsr, scr;
  // Lo que el driver devolvió, para compararlo contra lo que publicó el monitor.
  wishB_item done[$];

  function new(string name = "wishB_smoke_seq");
    super.new(name);
  endfunction

  task body();
    bit [7:0] ignored;
    access(1'b0, `UART_REG_LC, 8'h00, lcr);
    access(1'b0, `UART_REG_II, 8'h00, iir);
    access(1'b0, `UART_REG_LS, 8'h00, lsr);
    access(1'b1, `UART_REG_SR, scr_wdata, ignored);
    access(1'b0, `UART_REG_SR, 8'h00, scr);
  endtask

  // Sin adaptador del RAL todavía: el carril se calcula como lo hará reg2bus (uart_wb.v:293-298, big-endian).
  task access(input bit wr, input bit [`UART_ADDR_WIDTH-1:0] reg_n,
              input bit [7:0] wdata, output bit [7:0] rdata);
    wishB_item   it   = wishB_item::type_id::create("it");
    int unsigned lane = 3 - reg_n[1:0];

    start_item(it);
    if (!it.randomize() with {
          adr       == reg_n;
          we        == wr;
          sel       == (4'b1000 >> reg_n[1:0]);
          dat       == ({24'b0, wdata} << (8 * lane));
          delay     <= p_sequencer.cfg.wb_delay_max;
          stb_delay inside {[p_sequencer.cfg.wb_stb_delay_min : p_sequencer.cfg.wb_stb_delay_max]};
        })
      `uvm_fatal("SEQ", "No se pudo aleatorizar wishB_item")
    finish_item(it);

    rdata = it.dat[8 * lane +: 8];
    done.push_back(it);
    `uvm_info("SEQ", $sformatf("%s reg=%0d sel=%04b dat=0x%08h delay=%0d stb_delay=%0d",
                               wr ? "WR" : "RD", reg_n, it.sel, it.dat, it.delay, it.stb_delay), 300)
  endtask

endclass : wishB_smoke_seq
