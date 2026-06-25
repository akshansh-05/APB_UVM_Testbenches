`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_write_read_sequence extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_write_read_sequence)

  function new(string name = "apb_write_read_sequence");
    super.new(name);
  endfunction

  task body();
    apb_seq_item write_item;

    `uvm_info("SEQ", "=== STARTING WRITE TRANSFER ===", UVM_LOW)

    write_item = apb_seq_item::type_id::create("write_item");
    start_item(write_item);
    if (!write_item.randomize() with { read == 1'b0; }) begin
      `uvm_fatal("SEQ", "Randomization failed for write_item")
    end
    finish_item(write_item);
    `uvm_info("SEQ", $sformatf("Sent WRITE -> Addr: 0x%03h, Data: 0x%02h", write_item.addr, write_item.wdata), UVM_LOW)

    #50ns;
    `uvm_info("SEQ", "=== WRITE TRANSFER COMPLETED ===", UVM_LOW)
  endtask
endclass
