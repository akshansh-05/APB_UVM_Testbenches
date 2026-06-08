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

// =========================================================================
// UVM CONCEPT: The Sequencer & The Driver-Sequencer Pull Model
// =========================================================================
// The sequencer acts as a mediator and buffer between the active stimulus
// generator (the sequence) and the physical pin driver (the driver).
//
// The communication operates on a PULL model (initiated by the driver):
//   1. The driver calls `seq_item_port.get_next_item(req)`.
//   2. This call goes through the TLM export/port link to the sequencer.
//   3. The sequencer wakes up the running sequence's body.
//   4. The sequence generates a transaction item and sends it back.
//   5. Once the driver finishes driving the item, it calls `seq_item_port.item_done()`.
//   6. This handshakes back to the sequencer, unblocking the sequence.
//
// WHY TYPEDEF?
// UVM's `uvm_sequencer#(REQ, RSP)` is a fully implemented class that contains
// all the standard FIFOs, export ports, and complex arbitration logic (for
// cases where multiple sequences run concurrently).
//
// If you do not need to add custom variables, virtual interfaces, or write
// custom arbitration logic inside the sequencer, you do not need to extend
// the class. A simple `typedef` creates a type alias of the base class
// parameterized with your sequence item. This is clean and standard UVM practice.
// =========================================================================

// Parameterize the base sequencer with our transaction type.
typedef uvm_sequencer #(apb_master_seq_item) apb_master_sequencer;
