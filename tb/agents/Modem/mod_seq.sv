
class mod_seq extends uvm_sequence #(mod_pin_event);
  `uvm_object_utils(mod_seq)
  `uvm_declare_p_sequencer(mod_sequencer)

  int unsigned num_steps = 20;

  localparam int unsigned LONG_DELAY_MAX = 1000;

  function new(string name = "mod_seq");
    super.new(name);
  endfunction

  task body();
    mod_pin_event item;
    bit [3:0] current_pins = 4'b1111;
    bit [3:0] next_pins;
    int unsigned low_delay;
    int unsigned high_delay;

    if (p_sequencer.cfg == null)
      `uvm_fatal("MOD_SEQ", "No hay config_mod en mod_sequencer")

    p_sequencer.cfg.check_knobs();

    repeat (num_steps) begin

      next_pins = current_pins;

      // Cada entrada tiene su propia probabilidad de cambio.
      for (int i = 0; i < 4; i++) begin
        if ($urandom_range(99, 0) <
            p_sequencer.cfg.modem_change_pct)
          next_pins[i] = ~next_pins[i];
      end

      // 98 % de retardos cortos y 2 % de retardos largos.
      if ((p_sequencer.cfg.modem_delay_max < LONG_DELAY_MAX) &&
          ($urandom_range(99, 0) < 2)) begin
        low_delay  = p_sequencer.cfg.modem_delay_max + 1;
        high_delay = LONG_DELAY_MAX;
      end
      else begin
        low_delay  = 0;
        high_delay = p_sequencer.cfg.modem_delay_max;
      end

      item = mod_pin_event::type_id::create("item");

      start_item(item);

      if (!item.randomize() with {
        pin_inputs == local::next_pins;
        idle_clocks inside {[local::low_delay:local::high_delay]};
      })
        `uvm_fatal("MOD_SEQ",
                   "No se pudo aleatorizar mod_pin_event")

      finish_item(item);

      current_pins = next_pins;
    end
  endtask

endclass : mod_seq
