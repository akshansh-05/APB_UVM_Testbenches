// ============================================================================
// FILE: apb_master_pkg.sv
// DESCRIPTION:
//   Package that compiles all UVM testbench classes in dependency order.
//
//   WHY A PACKAGE?
//   In SystemVerilog, a package is a named scope that groups related types,
//   classes, and functions. By putting all UVM classes inside a package:
//     - They share a single compilation scope (can see each other)
//     - tb_top.sv just does "import apb_master_pkg::*" to access everything
//     - The `include order guarantees that each class is defined before
//       any class that depends on it
//
//   INCLUDE ORDER MATTERS:
//   Each `include brings the file's contents INTO this package scope.
//   A class must be defined before it can be referenced by another class.
//   For example, apb_master_agent.sv uses apb_master_driver, so driver
//   must be included first.
// ============================================================================

package apb_master_pkg;

  // Import the entire UVM base class library into this package.
  // This gives us access to uvm_driver, uvm_monitor, uvm_agent, etc.
  import uvm_pkg::*;

  // Include UVM macros (`uvm_component_utils, `uvm_info, `uvm_error, etc.)
  // These are preprocessor macros, not classes, so they use `include.
  `include "uvm_macros.svh"

  // ---- Include files in dependency order ----
  // Each file is included in the order that satisfies class dependencies:

  `include "apb_master_seq_item.sv"     // 1. Transaction item (no dependencies)
  `include "apb_master_sequencer.sv"    // 2. Sequencer typedef (depends on seq_item)
  `include "apb_master_driver.sv"       // 3. Driver (depends on seq_item)
  `include "apb_master_monitor.sv"      // 4. Monitor (depends on seq_item)
  `include "apb_master_agent.sv"        // 5. Agent (depends on driver, monitor, sequencer)
  `include "apb_master_scoreboard.sv"   // 6. Scoreboard (depends on seq_item)
  `include "apb_master_env.sv"          // 7. Environment (depends on agent, scoreboard)
  `include "apb_master_sequences.sv"    // 8. Sequences (depends on seq_item, sequencer)
  `include "apb_master_test.sv"         // 9. Test (depends on env, sequences)

endpackage
