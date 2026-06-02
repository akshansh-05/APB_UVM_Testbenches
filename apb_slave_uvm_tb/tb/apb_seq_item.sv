// ============================================================================
// FILE: apb_seq_item.sv
// DESCRIPTION:
//   The Sequence Item (also called a "transaction") is the fundamental data
//   object that flows through the UVM testbench.
//
//   Think of it as a "packet" that describes ONE APB transaction:
//     - What address to access?
//     - What data to write (if writing)?
//     - Is it a read or write?
//
//   The `rand` keyword means UVM can randomize these fields automatically.
//   Constraints limit randomization to legal values.
// ============================================================================

class apb_seq_item extends uvm_sequence_item;

  // ---- Randomizable Fields (inputs to the DUT) ----
  rand bit [7:0] addr;    // Address to read/write
  rand bit [7:0] wdata;   // Data to write
  rand bit       write;   // 1 = write transaction, 0 = read transaction

  // ---- Non-random Fields (outputs captured from DUT) ----
  bit [7:0] rdata;         // Data read back from the DUT

  // ---- Constraints ----
  // The slave's memory is only 64 entries deep (0-63).
  // We constrain addr to valid range for most tests.
  constraint valid_addr { addr inside {[0:63]}; }

  // ---- UVM Factory Registration ----
  // This macro registers this class with the UVM factory, enabling
  // features like type overriding and automatic object creation.
  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,  UVM_ALL_ON)
    `uvm_field_int(wdata, UVM_ALL_ON)
    `uvm_field_int(write, UVM_ALL_ON)
    `uvm_field_int(rdata, UVM_ALL_ON)
  `uvm_object_utils_end

  // ---- Constructor ----
  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  // ---- convert2string: For readable log messages ----
  function string convert2string();
    return $sformatf("addr=0x%02h wdata=0x%02h write=%0b rdata=0x%02h",
                     addr, wdata, write, rdata);
  endfunction

endclass
