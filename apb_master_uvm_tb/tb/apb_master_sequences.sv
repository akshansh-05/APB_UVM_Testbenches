// ============================================================================
// FILE: apb_master_sequences.sv
// DESCRIPTION:
//   Test sequences for the APB Master Bridge testbench.
//
//   A SEQUENCE generates a series of transactions (seq_items) and sends
//   them to the driver via the sequencer.
//
//   SEQUENCE EXECUTION FLOW:
//     1. Test calls: seq.start(env.agent.sqr)
//     2. Sequence's body() task runs
//     3. For each transaction:
//        a. start_item(item)  → waits for driver to be ready
//        b. item.randomize()  → randomizes the transaction fields
//        c. finish_item(item) → sends item to driver, waits for completion
//     4. After body() completes, seq.start() returns
//
//   We define 1 sequence:
//     1. apb_master_write_seq — Write transactions to Slave 1
// ============================================================================

// ============================================================================
// SEQUENCE 1: Write Sequence
// Sends 5 write transactions targeting Slave 1 (addr[8]=0).
// All addresses are constrained to the range [0:63] within Slave 1.
// ============================================================================
class apb_master_write_seq extends uvm_sequence #(apb_master_seq_item);

  // Register with UVM factory (uses `uvm_object_utils since sequences
  // are objects, not components — they don't have a parent in the hierarchy).
  `uvm_object_utils(apb_master_write_seq)

  // Number of transactions to generate. Can be changed before starting.
  int num_txns = 5;

  // ---- Constructor ----
  function new(string name = "apb_master_write_seq");
    super.new(name);
  endfunction

  // ---- body() task ----
  // This is the main execution task of the sequence.
  // It is called when the test does: seq.start(sequencer)
  task body();
    apb_master_seq_item item;  // Handle for each transaction

    `uvm_info("SEQ", $sformatf("Starting WRITE sequence: %0d transactions to Slave 1",
                                num_txns), UVM_MEDIUM)

    // Generate num_txns write transactions in a loop
    for (int i = 0; i < num_txns; i++) begin

      // Create a new transaction object via the factory
      item = apb_master_seq_item::type_id::create($sformatf("wr_%0d", i));

      // start_item() tells the sequencer "I have an item ready".
      // It BLOCKS until the driver calls get_next_item() — meaning
      // the driver is free and ready to accept a new transaction.
      start_item(item);

      // Randomize the item WITH inline constraints:
      //   read == 0        → force this to be a write transaction
      //   addr[8] == 0     → target Slave 1 (not Slave 2)
      //   addr[7:0] in [0:63] → valid address range within Slave 1
      // The "with { ... }" clause adds constraints ON TOP OF the
      // constraints defined inside the seq_item class (c_valid_addr).
      if (!item.randomize() with {
        read == 0;                // Write transaction
        addr[8] == 0;             // Target Slave 1
        addr[7:0] inside {[0:63]}; // Valid address range
      })
        `uvm_error("SEQ", "Randomization failed!")

      // finish_item() sends the randomized item to the driver.
      // It BLOCKS until the driver calls item_done() — meaning
      // the driver has fully processed this transaction on the bus.
      finish_item(item);
    end

    `uvm_info("SEQ", "WRITE sequence complete", UVM_MEDIUM)
  endtask

endclass

// ============================================================================
// SEQUENCE 2: Write Followed by Read Sequence (Self-Checking Scenario)
//
// UVM CONCEPT: Stimulus Decoupling & Late-Binding Randomization
//   1. Stimulus Decoupling: Sequences are completely decoupled from drivers.
//      They only know *what data* to generate, not *how* to drive it on wires.
//   2. Late-Binding: We create and register an item with `start_item()`, then
//      randomize it immediately before `finish_item()`. This ensures that
//      randomization constraints can adapt to the most current state of the RTL
//      (e.g., waiting until a buffer is not full).
//
//   In this sequence, we push addresses/data onto SystemVerilog queues during the
//   writes phase, and pop them during the reads phase to generate directed reads
//   matching exactly where we wrote.
// ============================================================================
class apb_master_write_read_seq extends uvm_sequence #(apb_master_seq_item);

  // Register with UVM factory. Sequences are transient (uvm_object), not components.
  `uvm_object_utils(apb_master_write_read_seq)

  // Number of write/read pairs to generate.
  int num_txns = 5;

  // SystemVerilog queues ($) acting as dynamic arrays.
  // These serve as a local "golden reference" to remember what we wrote so
  // we can read back from the exact same locations.
  bit [8:0] addr_q[$];
  bit [7:0] wdata_q[$];

  // ---- Constructor ----
  function new(string name = "apb_master_write_read_seq");
    super.new(name);
  endfunction

  // ---- body() task ----
  // The main execution thread of the sequence, called automatically when
  // the test starts the sequence via `seq.start(sequencer)`.
  task body();
    apb_master_seq_item item;

    `uvm_info("SEQ", $sformatf("Starting WRITE-READ sequence: %0d transactions", num_txns), UVM_MEDIUM)

    // ─────────────────────────────────────────────────────────────────────────
    // PHASE 1: Generate Write Transactions
    // ─────────────────────────────────────────────────────────────────────────
    for (int i = 0; i < num_txns; i++) begin
      // 1. Create a transaction instance via factory
      item = apb_master_seq_item::type_id::create($sformatf("wr_%0d", i));
      
      // 2. start_item() blocks until the sequencer permits generation.
      //    This is where the sequencer coordinates with the driver.
      start_item(item);
      
      // 3. Late-binding randomization with inline constraints:
      //    - read == 1'b0 (forces write transaction)
      //    - addr[7:0] restricted to [0:63] (lower addresses)
      if (!item.randomize() with {
        read == 1'b0; 
        addr[7:0] inside {[0:63]}; 
      }) begin
        `uvm_error("SEQ", "Write Randomization failed!")
      end
      
      // 4. Remember where we wrote and what we wrote
      addr_q.push_back(item.addr);
      wdata_q.push_back(item.wdata);
      
      // 5. finish_item() sends the randomized transaction to the driver
      //    and blocks until the driver calls item_done() (handshake complete).
      finish_item(item);
    end

    // ─────────────────────────────────────────────────────────────────────────
    // PHASE 2: Generate Read Transactions
    // ─────────────────────────────────────────────────────────────────────────
    for (int i = 0; i < num_txns; i++) begin
      // Retrieve the historical write address and data from the queues
      bit [8:0] rd_addr = addr_q.pop_front();
      bit [7:0] expected_val = wdata_q.pop_front();
      
      item = apb_master_seq_item::type_id::create($sformatf("rd_%0d", i));
      
      // Request permission from sequencer
      start_item(item);
      
      // Randomize the read command, forcing it to read from the exact address
      // we wrote to in Phase 1.
      if (!item.randomize() with {
        read == 1'b1;     // Read transaction
        addr == rd_addr;  // Directed address read
      }) begin
        `uvm_error("SEQ", "Read Randomization failed!")
      end
      
      // Send transaction to driver, wait for the bus read to complete
      finish_item(item);
      
      // At this point, finish_item() has returned. This means the driver
      // completed the read and updated the `rdata` field of the item.
      `uvm_info("SEQ", $sformatf("Read transaction completed: Addr=0x%03h, Expected Data=0x%02h, Got Data=0x%02h", 
                                  item.addr, expected_val, item.rdata), UVM_MEDIUM)
    end

    `uvm_info("SEQ", "WRITE-READ sequence complete", UVM_MEDIUM)
  endtask

endclass

