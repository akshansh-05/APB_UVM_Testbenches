// ============================================================================
// FILE: apb_pkg.sv
// DESCRIPTION:
//   The Package compiles all UVM class files in the correct dependency order.
//
//   WHY A PACKAGE?
//   --------------
//   SystemVerilog requires classes to be compiled before they are used.
//   A package ensures everything is compiled in the right order and
//   keeps all classes in a single namespace.
//
//   COMPILATION ORDER MATTERS:
//   seq_item → sequencer → driver → monitor → agent →
//   scoreboard → env → sequences → test
// ============================================================================

package apb_pkg;

  // Import the entire UVM library
  import uvm_pkg::*;

  // Include UVM macros (for `uvm_component_utils, `uvm_info, etc.)
  `include "uvm_macros.svh"

  // ---- Include files in dependency order ----
  // Each file defines one class. Order matters!

  `include "apb_seq_item.sv"     // 1. Transaction definition
  `include "apb_sequencer.sv"    // 2. Sequencer (uses seq_item)
  `include "apb_driver.sv"       // 3. Driver (uses seq_item)
  `include "apb_monitor.sv"      // 4. Monitor (uses seq_item)
  `include "apb_agent.sv"        // 5. Agent (uses driver, monitor, sequencer)
  `include "apb_scoreboard.sv"   // 6. Scoreboard (uses seq_item)
  `include "apb_env.sv"          // 7. Environment (uses agent, scoreboard)
  `include "apb_sequences.sv"    // 8. Sequences (uses seq_item)
  `include "apb_test.sv"         // 9. Test (uses env, sequences)

endpackage
