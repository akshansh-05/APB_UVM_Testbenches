package apb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Include order: dependency-driven (base types first)
  `include "apb_seq_item.sv"
  `include "apb_sequencer.sv"
  `include "apb_sys_driver.sv"
  // `include "apb_sys_monitor.sv"   // TODO: uncomment when adding monitor
  `include "apb_sys_agent.sv"
  `include "apb_slv_driver.sv"
  // `include "apb_monitor.sv"       // TODO: uncomment when adding bus monitor
  `include "apb_slv_agent.sv"
  // `include "apb_scoreboard.sv"    // TODO: uncomment when adding scoreboard
  `include "apb_env.sv"
  `include "apb_sequences.sv"
  `include "apb_test.sv"

endpackage : apb_pkg
