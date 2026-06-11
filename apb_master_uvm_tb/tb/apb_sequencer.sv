// =============================================================================
// FILE: apb_sequencer.sv
// DESCRIPTION:
//   APB Sequencer — a typedef alias for the standard UVM parameterized sequencer.
//
//   The sequencer acts as an arbitration point between stimulus sequences and
//   the system driver. It manages a FIFO of apb_seq_item transactions:
//     - Sequences push items via start_item()/finish_item()
//     - The driver pulls items via seq_item_port.get_next_item()
//
//   Since the APB sequencer needs no custom logic (no custom arbitration,
//   no response handling, no special variables), we use UVM's built-in
//   parameterized sequencer directly via typedef.
//
//   FLOW: Sequence → Sequencer FIFO → Driver
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// Parameterize the standard UVM sequencer with our apb_seq_item transaction type.
// This creates a sequencer that only accepts/delivers apb_seq_item objects.
typedef uvm_sequencer #(apb_seq_item) apb_sequencer;
