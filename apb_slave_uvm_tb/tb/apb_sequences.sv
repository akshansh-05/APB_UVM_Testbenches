// ============================================================================
// FILE: apb_sequences.sv
// DESCRIPTION:
//   Sequences define WHAT stimulus to send to the DUT.
//
//   A Sequence generates a stream of apb_seq_items and sends them to the
//   Sequencer, which forwards them to the Driver one at a time.
//
//   We define 3 sequences (simple to complex):
//     1. apb_write_seq       — Write random data to random addresses
//     2. apb_read_seq        — Read from random addresses
//     3. apb_write_read_seq  — Write known data, then read it back
//                               (this is the most useful test)
// ============================================================================

// ============================================================================
// SEQUENCE 1: Write Sequence
// Writes N random values to random addresses.
// ============================================================================
class apb_write_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_write_seq)

  // Number of write transactions to generate
  int num_txns = 5;

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item item;
    `uvm_info("SEQ", $sformatf("Starting WRITE sequence with %0d transactions", num_txns), UVM_MEDIUM)

    for (int i = 0; i < num_txns; i++) begin
      item = apb_seq_item::type_id::create($sformatf("write_item_%0d", i));

      start_item(item);           // Request permission from sequencer
      if (!item.randomize() with { write == 1; })   // Force write=1
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);          // Send to driver and wait for completion
    end

    `uvm_info("SEQ", "WRITE sequence complete", UVM_MEDIUM)
  endtask

endclass

// ============================================================================
// SEQUENCE 2: Read Sequence
// Reads from N random addresses.
// ============================================================================
class apb_read_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_read_seq)

  int num_txns = 5;

  function new(string name = "apb_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item item;
    `uvm_info("SEQ", $sformatf("Starting READ sequence with %0d transactions", num_txns), UVM_MEDIUM)

    for (int i = 0; i < num_txns; i++) begin
      item = apb_seq_item::type_id::create($sformatf("read_item_%0d", i));

      start_item(item);
      if (!item.randomize() with { write == 0; })   // Force write=0
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    `uvm_info("SEQ", "READ sequence complete", UVM_MEDIUM)
  endtask

endclass

// ============================================================================
// SEQUENCE 3: Write-then-Read Sequence (THE MAIN TEST)
// Writes known data to addresses 0-4, then reads them back.
// The Scoreboard will automatically check if read data matches written data.
// This is the sequence that will expose RTL bugs!
// ============================================================================
class apb_write_read_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_write_read_seq)

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item item;

    `uvm_info("SEQ", "=== Starting WRITE-then-READ sequence ===", UVM_LOW)

    // ------ Phase 1: Write known data to addresses 0 through 4 ------
    `uvm_info("SEQ", "Phase 1: Writing data...", UVM_LOW)
    for (int i = 0; i < 5; i++) begin
      item = apb_seq_item::type_id::create($sformatf("wr_item_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        write == 1;
        addr  == i;            // Write to address 0, 1, 2, 3, 4
        wdata == (i * 10);     // Write values 0, 10, 20, 30, 40
      })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    // ------ Phase 2: Read back from the same addresses ------
    `uvm_info("SEQ", "Phase 2: Reading back data...", UVM_LOW)
    for (int i = 0; i < 5; i++) begin
      item = apb_seq_item::type_id::create($sformatf("rd_item_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        write == 0;
        addr  == i;            // Read from same addresses
      })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    `uvm_info("SEQ", "=== WRITE-then-READ sequence complete ===", UVM_LOW)
  endtask

endclass
