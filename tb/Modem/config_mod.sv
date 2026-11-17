class config_mod extends uvm_object ;
    `uvm_object_utils(config_mod)
    
    int unsigned modem_delay_max = 50 ;
    int unsigned modem_change_pct = 50;
    int unsigned mcr_loopback_pct = 20;
    int unsigned mcr_weights[4] = '{50, 50, 50, 50};
    int unsigned ier_weights[4] = '{50, 50, 50, 50};

    function new(string name = "config_mod");
        super.new(name);
    endfunction

//los pesos de mcr e ier representan la probabilidad de que cada bit se active
function void check_knobs ();

    if(modem_change_pct > 100) begin
        `uvm_fatal("CONFIG ERROR", "modem_change_pct debe ser menor o igual a 100")
    end
    
    if(mcr_loopback_pct > 100) begin
        `uvm_fatal("CONFIG ERROR", "mcr_loopback_pct debe ser menor o igual a 100")
    end

    foreach (mcr_weights[i]) begin 
            if (mcr_weights[i] > 100) begin
             `uvm_fatal("CFG", $sformatf("mcr_weights[%0d] debe ser menor o igual a 100", i))
            end
    end 

    foreach (ier_weights[i]) begin 
        if (ier_weights[i] > 100) begin
        `uvm_fatal("CFG",$sformatf("UART_IER_WEIGTHS[%0d] debe ser menor o igual a 100", i));
        end
    end
endfunction
endclass : config_mod