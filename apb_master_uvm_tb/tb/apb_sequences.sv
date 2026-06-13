`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_write_read_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_write_read_seq)

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item write_item;
    // apb_seq_item read_item;  // TODO: uncomment when adding read support

    `uvm_info("SEQ", "Starting WRITE-only sequence", UVM_LOW)

    // WRITE TRANSACTION
    write_item = apb_seq_item::type_id::create("write_item");
    start_item(write_item);

    if (!write_item.randomize() with {
      read == 1'b0;    // Force write
    }) begin
      `uvm_error("SEQ", "Write randomization failed!")
    end

    `uvm_info("SEQ", $sformatf("Sending Write: Addr=0x%03h, Data=0x%02h", write_item.addr, write_item.wdata), UVM_LOW)
    finish_item(write_item);

    // TODO: uncomment when adding read-back verification
    // read_item = apb_seq_item::type_id::create("read_item");
    // start_item(read_item);
    // if (!read_item.randomize() with {
    //   read == 1'b1;
    //   addr == write_item.addr;
    // }) begin
    //   `uvm_error("SEQ", "Read randomization failed!")
    // end
    // `uvm_info("SEQ", $sformatf("Sending Read: Addr=0x%03h", read_item.addr), UVM_LOW)
    // finish_item(read_item);

    `uvm_info("SEQ", "WRITE sequence complete", UVM_LOW)
  endtask

endclass
