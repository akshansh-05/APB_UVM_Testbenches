//     1. apb_write_seq       — Write random data to random addresses
//     2. apb_read_seq        — Read from random addresses
//     3. apb_write_read_seq  — Write known data, then read it back

// SEQUENCE 1: Write Sequence
// The test sequence generates transaction stimuli (writes followed by reads)
// and drives them on the system sequencer interface.
class apb_write_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_write_seq)

  int num_txns = 5;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

    // Body: sequence body containing the transaction generation and randomization loops
  task body();
    apb_seq_item item;
    `uvm_info("SEQ", $sformatf("Starting WRITE sequence with %0d transactions", num_txns), UVM_MEDIUM)

    for (int i = 0; i < num_txns; i++) begin
      item = apb_seq_item::type_id::create($sformatf("write_item_%0d", i));

      start_item(item);
      if (!item.randomize() with { write == 1; })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    `uvm_info("SEQ", "WRITE sequence complete", UVM_MEDIUM)
  endtask

endclass

// SEQUENCE 2: Read Sequence
// Reads from N random addresses.
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
      if (!item.randomize() with { write == 0; })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

    `uvm_info("SEQ", "READ sequence complete", UVM_MEDIUM)
  endtask

endclass

// Writes known data to addresses 0-4, then reads them back.
// This is the sequence that will expose RTL bugs!
class apb_write_read_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_write_read_seq)

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item item;

    `uvm_info("SEQ", "=== Starting WRITE-then-READ sequence ===", UVM_LOW)

    `uvm_info("SEQ", "Phase 1: Writing data...", UVM_LOW)
    for (int i = 0; i < 5; i++) begin
      item = apb_seq_item::type_id::create($sformatf("wr_item_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        write == 1;
        addr  == i;            // Write to address 0, 1, 2, 3, 4
        wdata == (i * 10);
      })
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(item);
    end

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
