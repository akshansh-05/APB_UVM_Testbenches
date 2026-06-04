// ============================================================================
// FILE: apb_master_seq_item.sv
// DESCRIPTION:
//   Transaction class for the APB Master Bridge testbench.
//
//   This item serves TWO roles:
//     1. DRIVER uses it to know WHAT transfer to request
//        (addr, wdata, read fields are randomized)
//     2. MONITOR uses it to record WHAT actually happened on the APB bus
//        (paddr, pwdata, pwrite, rdata, psel1, psel2, pslverr are captured)
//
//   The Scoreboard then uses the monitored fields to check correctness.
// ============================================================================

class apb_master_seq_item extends uvm_sequence_item;

  // ---- Driver Fields (system-side, randomizable) ----
  rand bit [8:0] addr;    // Address for transfer (bit[8] selects slave)
  rand bit [7:0] wdata;   // Data to write
  rand bit       read;    // 1 = read transaction, 0 = write transaction

  // ---- Monitor Fields (APB bus outputs, captured by monitor) ----
  bit [8:0] paddr;              // Observed PADDR on APB bus
  bit [7:0] pwdata;             // Observed PWDATA on APB bus
  bit       pwrite;             // Observed PWRITE signal
  bit [7:0] rdata;              // Observed apb_read_data_out
  bit       psel1;              // Observed PSEL1
  bit       psel2;              // Observed PSEL2
  bit       pslverr;            // Observed PSLVERR

  // ---- Constraints ----
  // addr[8] selects the slave: 0 = Slave1, 1 = Slave2
  // addr[7:0] is the actual address within the slave
  constraint c_valid_addr { addr inside {[0:511]}; }

  // ---- UVM Factory Registration ----
  `uvm_object_utils_begin(apb_master_seq_item)
    `uvm_field_int(addr,    UVM_ALL_ON)
    `uvm_field_int(wdata,   UVM_ALL_ON)
    `uvm_field_int(read,    UVM_ALL_ON)
    `uvm_field_int(paddr,   UVM_ALL_ON)
    `uvm_field_int(pwdata,  UVM_ALL_ON)
    `uvm_field_int(pwrite,  UVM_ALL_ON)
    `uvm_field_int(rdata,   UVM_ALL_ON)
    `uvm_field_int(psel1,   UVM_ALL_ON)
    `uvm_field_int(psel2,   UVM_ALL_ON)
    `uvm_field_int(pslverr, UVM_ALL_ON)
  `uvm_object_utils_end

  // ---- Constructor ----
  function new(string name = "apb_master_seq_item");
    super.new(name);
  endfunction

  // ---- convert2string: Human-readable log output ----
  virtual function string convert2string();
    return $sformatf("addr=0x%03h wdata=0x%02h read=%0b | paddr=0x%03h pwdata=0x%02h pwrite=%0b rdata=0x%02h psel1=%0b psel2=%0b pslverr=%0b",
                     addr, wdata, read, paddr, pwdata, pwrite, rdata, psel1, psel2, pslverr);
  endfunction

endclass
