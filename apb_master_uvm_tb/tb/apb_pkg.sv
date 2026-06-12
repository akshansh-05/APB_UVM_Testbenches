// =============================================================================
// FILE: apb_pkg.sv
// DESCRIPTION:
//   APB Package — a single compilation unit that wraps ALL UVM testbench classes.
//
//   PURPOSE:
//     SystemVerilog packages provide namespace scoping and compilation ordering.
//     By including all class files inside a package:
//       1. All classes share the same compilation scope (can reference each other)
//       2. The include order guarantees dependency resolution
//       3. tb_top.sv only needs `import apb_pkg::*` to access everything
//
//   INCLUDE ORDER (dependency-driven):
//     1. apb_seq_item   — transaction data container (no dependencies)
//     2. apb_sequencer   — parameterized with apb_seq_item
//     3. apb_sys_driver  — uses apb_seq_item
//     4. apb_sys_monitor — uses apb_seq_item
//     5. apb_sys_agent   — uses driver, monitor, sequencer
//     6. apb_slv_driver  — uses apb_seq_item
//     7. apb_monitor     — uses apb_seq_item (inside slave agent)
//     8. apb_slv_agent   — uses slv_driver, monitor, sequencer
//     9. apb_scoreboard  — uses apb_seq_item
//    10. apb_env         — uses all agents, monitor, scoreboard
//    11. apb_sequences   — uses apb_seq_item
//    12. apb_test        — uses apb_env and sequences
//
//   NOTE: apb_if.sv is NOT included here because interfaces cannot be declared
//   inside packages. It is compiled separately as a standalone file.
// =============================================================================

package apb_pkg;

  import uvm_pkg::*;          // Import the UVM base library
  `include "uvm_macros.svh"   // Include UVM macros (uvm_info, uvm_error, etc.)

  // Include all class files in strict dependency order
  `include "apb_seq_item.sv"      // 1.  Transaction packet class
  `include "apb_sequencer.sv"     // 2.  Sequencer typedef
  `include "apb_sys_driver.sv"    // 3.  System-side active driver
  `include "apb_sys_monitor.sv"   // 4.  System-side passive monitor
  `include "apb_sys_agent.sv"     // 5.  System-side agent container
  `include "apb_slv_driver.sv"    // 6.  Reactive slave driver
  `include "apb_monitor.sv"       // 7.  APB bus monitor (inside slave agent)
  `include "apb_slv_agent.sv"     // 8.  Slave agent container
  `include "apb_scoreboard.sv"    // 9.  Verification checker scoreboard
  `include "apb_env.sv"           // 10. Environment container
  `include "apb_sequences.sv"     // 11. Stimulus sequences
  `include "apb_test.sv"          // 12. Test classes

endpackage : apb_pkg
