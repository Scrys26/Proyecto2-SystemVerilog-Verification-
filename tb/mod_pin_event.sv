class mod_pin_event extends uvm_sequence_item;
    rand logic [3:0] pin_inputs; // CTS, DSR, RI, DCD
    logic [1:0] pin_outputs; // RTS, DTR
    rand int unsigned idle_clocks; 
    `uvm_object_utils(mod_pin_event)
       `uvm_field_int(pin_inputs, UVM_ALL_ON)
       `uvm_field_int(pin_outputs, UVM_ALL_ON)
       `uvm_field_int(idle_clocks, UVM_ALL_ON)
    `uvm_object_utils_end
    function new (string name = "mod_pin_event")
        super.new(name);
    endfunction
endclass : mod_pin_event
