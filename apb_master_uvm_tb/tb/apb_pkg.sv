// ============================================================================
// FILE: apb_pkg.sv
// DESCRIPTION: Package that compiles all UVM testbench classes in dependency order.
// ============================================================================

package apb_pkg;                                          // Named package scope grouping all UVM classes

  import uvm_pkg::*;                                     // Imports standard UVM library package scope

  `include "uvm_macros.svh"                              // Includes standard preprocessor macros (uvm_info, etc.)

  `include "apb_seq_item.sv"                             // 1. Transaction definition (has no class dependencies)
  `include "apb_sequencer.sv"                            // 2. Sequencer definition (depends on apb_seq_item)
  `include "apb_sys_driver.sv"                           // 3. System driver (depends on apb_seq_item)
  `include "apb_sys_monitor.sv"                          // 4. System monitor (depends on apb_seq_item)
  `include "apb_sys_agent.sv"                            // 5. System agent (depends on driver, sequencer, monitor)
  `include "apb_slv_driver.sv"                           // 6. Slave driver (depends on apb_seq_item)
  `include "apb_slv_agent.sv"                            // 7. Slave agent (depends on slave driver)
  `include "apb_monitor.sv"                              // 8. Standalone APB monitor (depends on apb_seq_item)
  `include "apb_scoreboard.sv"                           // 9. Scoreboard checker (depends on apb_seq_item)
  `include "apb_env.sv"                                  // 10. Environment container (depends on agents, monitor, scoreboard)
  `include "apb_sequences.sv"                            // 11. Stimulus sequences (depends on seq_item and sequencer)
  `include "apb_test.sv"                                 // 12. System test scenarios (depends on env and sequences)

endpackage : apb_pkg                                      // End of package declaration
