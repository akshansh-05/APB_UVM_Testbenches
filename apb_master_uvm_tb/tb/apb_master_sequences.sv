// ============================================================================
// FILE: apb_master_sequences.sv
// DESCRIPTION:
//   Test sequences for the APB Master Bridge testbench.
//
//   We define 3 sequences that exercise different aspects of the master:
//     1. apb_master_write_seq     — Write transactions to Slave 1
//     2. apb_master_read_seq      — Read transactions from Slave 1
//     3. apb_master_mixed_seq     — Writes + reads to BOTH slaves
//                                   (the main test sequence)
// ============================================================================

// ============================================================================
// SEQUENCE 1: Write Sequence
// Sends 5 write transactions targeting Slave 1 (addr[8]=0).
// ============================================================================
class apb_master_write_seq extends uvm_sequence #(apb_master_seq_item);

  `uvm_object_utils(apb_master_write_seq)

  int num_txns = 5;

  function new(string name = "apb_master_write_seq");
    super.new(name);
  endfunction

  task body();
    apb_master_seq_item item;
    `uvm_info("SEQ", $sformatf("Starting WRITE sequence: %0d transactions to Slave 1",
                                num_txns), UVM_MEDIUM)

    for (int i = 0; i < num_txns; i++) begin
      item = apb_master_seq_item::type_id::create($sformatf("wr_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        read == 0;                // Write transaction
        addr[8] == 0;             // Target Slave 1
        addr[7:0] inside {[0:63]}; // Valid address range
      })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    `uvm_info("SEQ", "WRITE sequence complete", UVM_MEDIUM)
  endtask

endclass

// ============================================================================
// SEQUENCE 2: Read Sequence
// Sends 5 read transactions targeting Slave 1 (addr[8]=0).
// The slave responder returns PRDATA = PADDR[7:0] ^ 0xA5.
// The scoreboard verifies apb_read_data_out matches this pattern.
// ============================================================================
class apb_master_read_seq extends uvm_sequence #(apb_master_seq_item);

  `uvm_object_utils(apb_master_read_seq)

  int num_txns = 5;

  function new(string name = "apb_master_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_master_seq_item item;
    `uvm_info("SEQ", $sformatf("Starting READ sequence: %0d transactions from Slave 1",
                                num_txns), UVM_MEDIUM)

    for (int i = 0; i < num_txns; i++) begin
      item = apb_master_seq_item::type_id::create($sformatf("rd_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        read == 1;                // Read transaction
        addr[8] == 0;             // Target Slave 1
        addr[7:0] inside {[0:63]};
      })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    `uvm_info("SEQ", "READ sequence complete", UVM_MEDIUM)
  endtask

endclass

// ============================================================================
// SEQUENCE 3: Mixed Sequence (THE MAIN TEST)
// Tests both slaves and both read/write operations:
//   Phase 1: 3 writes to Slave 1 (addr[8]=0)
//   Phase 2: 3 reads from Slave 1  → Scoreboard checks read data
//   Phase 3: 2 writes to Slave 2 (addr[8]=1)
//   Phase 4: 2 reads from Slave 2  → Scoreboard checks read data
//
// This sequence verifies:
//   - FSM transitions (IDLE → SETUP → ENABLE → IDLE)
//   - Address routing (PSEL1 vs PSEL2)
//   - Data pass-through (write and read paths)
// ============================================================================
class apb_master_mixed_seq extends uvm_sequence #(apb_master_seq_item);

  `uvm_object_utils(apb_master_mixed_seq)

  function new(string name = "apb_master_mixed_seq");
    super.new(name);
  endfunction

  task body();
    apb_master_seq_item item;

    `uvm_info("SEQ", "=== Starting MIXED sequence (both slaves, R+W) ===", UVM_LOW)

    // ---- Phase 1: Write to Slave 1 (addr[8]=0) ----
    `uvm_info("SEQ", "Phase 1: Writing to Slave 1...", UVM_LOW)
    for (int i = 0; i < 3; i++) begin
      item = apb_master_seq_item::type_id::create($sformatf("s1_wr_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        read == 0;
        addr == (i * 4);            // Addresses: 0x000, 0x004, 0x008
        wdata == (i * 11);          // Data: 0, 11, 22
      })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    // ---- Phase 2: Read from Slave 1 ----
    `uvm_info("SEQ", "Phase 2: Reading from Slave 1...", UVM_LOW)
    for (int i = 0; i < 3; i++) begin
      item = apb_master_seq_item::type_id::create($sformatf("s1_rd_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        read == 1;
        addr == (i * 4);            // Same addresses
      })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    // ---- Phase 3: Write to Slave 2 (addr[8]=1) ----
    `uvm_info("SEQ", "Phase 3: Writing to Slave 2...", UVM_LOW)
    for (int i = 0; i < 2; i++) begin
      item = apb_master_seq_item::type_id::create($sformatf("s2_wr_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        read == 0;
        addr == (9'h100 + i * 4);   // Addresses: 0x100, 0x104 (bit[8]=1)
        wdata == (i * 33);           // Data: 0, 33
      })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    // ---- Phase 4: Read from Slave 2 ----
    `uvm_info("SEQ", "Phase 4: Reading from Slave 2...", UVM_LOW)
    for (int i = 0; i < 2; i++) begin
      item = apb_master_seq_item::type_id::create($sformatf("s2_rd_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        read == 1;
        addr == (9'h100 + i * 4);
      })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    `uvm_info("SEQ", "=== MIXED sequence complete ===", UVM_LOW)
  endtask

endclass
