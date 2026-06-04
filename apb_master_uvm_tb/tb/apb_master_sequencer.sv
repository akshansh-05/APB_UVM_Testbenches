// ============================================================================
// FILE: apb_master_sequencer.sv
// DESCRIPTION:
//   Sequencer for the APB Master testbench.
//
//   The sequencer acts as a FIFO (First-In-First-Out) buffer between
//   the Sequence (which generates transactions) and the Driver (which
//   drives them onto the DUT).
//
//   FLOW:  Sequence → Sequencer → Driver
//          (creates)   (queues)    (consumes)
//
//   WHY JUST A TYPEDEF?
//   The UVM library provides a fully functional parameterized sequencer
//   class: uvm_sequencer #(REQ). It already has:
//     - A FIFO to buffer sequence items
//     - seq_item_export port (connected to the driver's seq_item_port)
//     - Arbitration for multiple sequences running in parallel
//     - All standard UVM component phases (build, connect, run, etc.)
//
//   Since we don't need any custom sequencer logic (no extra fields,
//   no special arbitration, no virtual interface), we just create a
//   type alias. This is equivalent to writing a full class that adds
//   nothing to the base class — but is cleaner and less code.
//
//   WHERE IS THIS ALIAS USED?
//     - apb_master_agent.sv: declares "apb_master_sequencer sqr;"
//     - apb_master_test.sv:  calls "seq.start(env.agent.sqr);"
// ============================================================================

// "typedef" creates a new type name "apb_master_sequencer" that is
// identical to "uvm_sequencer #(apb_master_seq_item)".
// The #(apb_master_seq_item) parameterization tells the sequencer
// what type of transaction items it will handle.
typedef uvm_sequencer #(apb_master_seq_item) apb_master_sequencer;
