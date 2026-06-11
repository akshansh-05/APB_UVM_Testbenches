// =============================================================================
// FILE: apb_sequences.sv
// DESCRIPTION:
//   APB Stimulus Sequence — generates the transaction-level stimulus that
//   drives the APB Master DUT through the system-side agent.
//
//   This file contains the apb_write_read_seq sequence, which implements
//   the "write-then-read-back" verification pattern:
//
//   PHASE 1 — WRITE:
//     Creates a randomized write transaction (read=0) with random address and
//     data. Drives it through the system agent to perform an APB write transfer.
//     Saves the randomized address and data for Phase 2.
//
//   PHASE 2 — READ-BACK:
//     Creates a read transaction (read=1) targeting the EXACT SAME ADDRESS
//     that was written in Phase 1. This verifies that:
//       a. The slave stored the write data correctly
//       b. The master reads it back correctly
//       c. The data path through the entire DUT is intact
//
//   VERIFICATION FLOW:
//     Sequence → Sequencer → sys_driver → DUT → slave_driver (stores data)
//     Sequence → Sequencer → sys_driver → DUT → slave_driver (returns data)
//     Monitors capture both transactions → Scoreboard compares write vs read data
//
//   The scoreboard's ref_mem will have the write data stored, and when the
//   read-back occurs, it compares the bus read data against ref_mem — producing
//   a PASS if they match, or a FAIL (UVM_ERROR) if they don't.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_write_read_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_write_read_seq)    // Register with UVM factory

  // ---------------------------------------------------------------------------
  // SAVED WRITE PARAMETERS
  // These variables store the randomized write address and data so the
  // subsequent read can target the exact same address for verification.
  // ---------------------------------------------------------------------------
  bit [8:0] target_addr;     // Address used for the write (saved for read-back)
  bit [7:0] target_wdata;    // Data written (saved for log comparison)

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  // BODY — main sequence logic
  //
  // This task executes when the sequence is started on a sequencer via:
  //   seq.start(env.sys_agent.sqr);
  //
  // The start_item()/finish_item() protocol:
  //   start_item(item)  — requests access to the sequencer (blocks until granted)
  //   [randomize item]  — set the transaction fields
  //   finish_item(item) — sends item to driver, blocks until driver calls item_done()
  // ---------------------------------------------------------------------------
  task body();
    apb_seq_item write_item;
    apb_seq_item read_item;

    `uvm_info("SEQ", "Starting simplified WRITE-READ sequence", UVM_MEDIUM)

    // =====================================================================
    // PHASE 1: WRITE TRANSACTION
    // Create and send a write transaction with randomized address and data.
    // The constraint solver picks random addr and wdata; we only force read=0.
    // =====================================================================
    write_item = apb_seq_item::type_id::create("write_item");
    start_item(write_item);    // Request sequencer access (blocking)

    // Randomize with inline constraint: force write direction (read=0)
    // Address and wdata are freely randomized by the solver
    if (!write_item.randomize() with {
      read == 1'b0;    // Force write transfer
    }) begin
      `uvm_error("SEQ", "Write randomization failed!")
    end

    // Save the randomized values for Phase 2 read-back verification
    target_addr  = write_item.addr;
    target_wdata = write_item.wdata;

    `uvm_info("SEQ", $sformatf("Sending Write: Addr=0x%03h, Data=0x%02h", write_item.addr, write_item.wdata), UVM_MEDIUM)

    finish_item(write_item);    // Send to driver, block until APB handshake completes

    // =====================================================================
    // PHASE 2: READ-BACK TRANSACTION
    // Create a read transaction targeting the SAME ADDRESS that was written.
    // After the driver completes the read, rdata will contain the data
    // returned by the slave — which should match what was written.
    // =====================================================================
    read_item = apb_seq_item::type_id::create("read_item");
    start_item(read_item);    // Request sequencer access (blocking)

    // Randomize with inline constraints:
    //   - Force read direction (read=1)
    //   - Force address to the SAME address we wrote to (target_addr)
    if (!read_item.randomize() with {
      read == 1'b1;              // Force read transfer
      addr == target_addr;       // Read from the exact address we just wrote to
    }) begin
      `uvm_error("SEQ", "Read randomization failed!")
    end

    `uvm_info("SEQ", $sformatf("Sending Read: Addr=0x%03h", read_item.addr), UVM_MEDIUM)

    finish_item(read_item);    // Send to driver, block until APB handshake completes

    // Log the read-back result for debug visibility
    // The actual PASS/FAIL check happens in the scoreboard, not here
    `uvm_info("SEQ", $sformatf("Read Completed: Addr=0x%03h, Expected Data=0x%02h, Got Data=0x%02h", read_item.addr, target_wdata, read_item.rdata), UVM_MEDIUM)

    `uvm_info("SEQ", "WRITE-READ sequence complete", UVM_MEDIUM)
  endtask

endclass
