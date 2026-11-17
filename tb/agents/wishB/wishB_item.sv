// Transacción Wishbone a nivel de bus: lo que el driver mueve y el monitor 
// reconstruye.
// Ref: F-WB-01, V-WB-01, V-WB-02. Dueño: Eric.
class wishB_item extends uvm_sequence_item;

  rand bit [`UART_ADDR_WIDTH-1:0] adr;
  rand bit [3:0]                  sel;
  rand bit                        we;
  rand bit [`UART_DATA_WIDTH-1:0] dat;    // en lectura se sobrescribe con dat_s2m
  rand int unsigned               delay;  // ciclos antes de la transferencia
  rand int unsigned               stb_delay; // ciclos con cyc = 1 y stb = 0
  int unsigned                    ack_lat; // lo llena el monitor; solo para depuración
  uvm_status_e                    status = UVM_IS_OK; // lo llena el driver; el adaptador lo pasa al RAL

  constraint c_sel   { soft $countones(sel) == 1; }

  `uvm_object_utils_begin(wishB_item)
    `uvm_field_int(adr,     UVM_ALL_ON)
    `uvm_field_int(sel,     UVM_ALL_ON)
    `uvm_field_int(we,      UVM_ALL_ON)
    `uvm_field_int(dat,     UVM_ALL_ON)
    `uvm_field_int(delay,     UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(stb_delay, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(ack_lat,   UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_enum(uvm_status_e, status, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "wishB_item");
    super.new(name);
  endfunction

endclass