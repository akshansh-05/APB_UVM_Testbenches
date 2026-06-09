//   SystemVerilog requires classes to be compiled before they are used.
//   keeps all classes in a single namespace.

package apb_pkg;

  import uvm_pkg::*;

  `include "uvm_macros.svh"

  `include "apb_seq_item.sv"
  `include "apb_sequencer.sv"
  `include "apb_driver.sv"
  `include "apb_monitor.sv"
  `include "apb_agent.sv"
  `include "apb_scoreboard.sv"
  `include "apb_env.sv"
  `include "apb_sequences.sv"    // 8. Sequences (uses seq_item)
  `include "apb_test.sv"

endpackage
