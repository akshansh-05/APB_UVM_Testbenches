// The test sequence generates transaction stimuli (writes followed by reads)
// and drives them on the system sequencer interface.
class apb_write_read_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_write_read_seq)

  bit [8:0] target_addr;
  bit [7:0] target_wdata;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

    // Body: sequence body containing the transaction generation and randomization loops
  task body();                                           // Body task where sequence logic runs
    apb_seq_item write_item;
    apb_seq_item read_item;

    `uvm_info("SEQ", "Starting simplified WRITE-READ sequence", UVM_MEDIUM)

    // ── Phase 1: Write Transaction ──
    write_item = apb_seq_item::type_id::create("write_item");
    start_item(write_item);
    if (!write_item.randomize() with {
      read == 1'b0;
      addr[8] == 1'b0;                                   // Targets Slave 1 (address bit 8 is low)
      addr[7:0] == 8'h10;
      wdata == 8'hBE;
    }) begin
      `uvm_error("SEQ", "Write randomization failed!")
    end

    target_addr  = write_item.addr;
    target_wdata = write_item.wdata;

    `uvm_info("SEQ", $sformatf("Sending Write: Addr=0x%03h, Data=0x%02h", write_item.addr, write_item.wdata), UVM_MEDIUM)

    finish_item(write_item);

    // ── Phase 2: Read Transaction ──
    read_item = apb_seq_item::type_id::create("read_item");
    start_item(read_item);
    if (!read_item.randomize() with {
      read == 1'b1;
      addr == target_addr;                               // Forces read from the exact address written previously
    }) begin
      `uvm_error("SEQ", "Read randomization failed!")
    end

    `uvm_info("SEQ", $sformatf("Sending Read: Addr=0x%03h", read_item.addr), UVM_MEDIUM)

    finish_item(read_item);

    `uvm_info("SEQ", $sformatf("Read Completed: Addr=0x%03h, Expected Data=0x%02h, Got Data=0x%02h", read_item.addr, target_wdata, read_item.rdata), UVM_MEDIUM)

    `uvm_info("SEQ", "WRITE-READ sequence complete", UVM_MEDIUM)
  endtask

endclass
