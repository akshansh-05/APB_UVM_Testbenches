// ============================================================================
// FILE: apb_master_sequences.sv
// DESCRIPTION:
//   Test sequences for the APB Master Bridge testbench.
//
//   We define 1 sequence that exercises different aspects of the master:
//     1. apb_master_write_seq     — Write transactions to Slave 1
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
