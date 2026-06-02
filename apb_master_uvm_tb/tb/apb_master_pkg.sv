// ============================================================================
// FILE: apb_master_pkg.sv
// DESCRIPTION:
//   Package that compiles all UVM classes in dependency order.
//   Same concept as the slave TB package.
// ============================================================================

package apb_master_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Include files in dependency order
  `include "apb_master_seq_item.sv"     // 1. Transaction
  `include "apb_master_sequencer.sv"    // 2. Sequencer
  `include "apb_master_driver.sv"       // 3. Driver
  `include "apb_master_monitor.sv"      // 4. Monitor
  `include "apb_master_agent.sv"        // 5. Agent
  `include "apb_master_scoreboard.sv"   // 6. Scoreboard
  `include "apb_master_env.sv"          // 7. Environment
  `include "apb_master_sequences.sv"    // 8. Sequences
  `include "apb_master_test.sv"         // 9. Test

endpackage
