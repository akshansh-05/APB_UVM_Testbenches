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
