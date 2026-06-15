`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_sequence extends uvm_sequence #(apb_seq_item);

    `uvm_object_utils(apb_sequence)

    function new (string name ="apb_sequence");
        super.new(name);
    endfunction

    task body();
        apb_seq_item item;

        item = apb_seq_item::type_id::create("item");

        start_item(item);

        assert(item.randomize());
        `uvm_info("SEQ","randomization completed", UVM_LOW)

        finish_item(item);
        `uvm_info("SEQ",item.sprint(),UVM_LOW)
    endtask

endclass