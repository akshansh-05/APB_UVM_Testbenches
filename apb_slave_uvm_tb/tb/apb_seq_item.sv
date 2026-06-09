//     - What address to access?
//     - What data to write (if writing)?
//     - Is it a read or write?

class apb_seq_item extends uvm_sequence_item;

  rand bit [7:0] addr;
  rand bit [7:0] wdata;
  rand bit       write;   // 1 = write transaction, 0 = read transaction

  bit [7:0] rdata;         // Data read back from the DUT

  // The slave's memory is only 64 entries deep (0-63).
  constraint valid_addr { addr inside {[0:63]}; }

  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,  UVM_ALL_ON)
    `uvm_field_int(wdata, UVM_ALL_ON)
    `uvm_field_int(write, UVM_ALL_ON)
    `uvm_field_int(rdata, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("addr=0x%02h wdata=0x%02h write=%0b rdata=0x%02h",
                     addr, wdata, write, rdata);
  endfunction

endclass
