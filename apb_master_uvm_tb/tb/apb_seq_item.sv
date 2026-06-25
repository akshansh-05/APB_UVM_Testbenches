`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_seq_item extends uvm_sequence_item;

  // Stimulus fields
  rand bit [8:0] addr;
  rand bit [7:0] wdata;
  rand bit       read;

  // Monitor fields
  bit [8:0] paddr;
  bit [7:0] pwdata;
  bit       pwrite;
  bit [7:0] rdata;
  bit       psel1;
  bit       psel2;
  bit       penable;

  constraint c_valid_addr { 
    addr inside {[0:511]}; 
  }

  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,    UVM_ALL_ON)
    `uvm_field_int(wdata,   UVM_ALL_ON)
    `uvm_field_int(read,    UVM_ALL_ON)
    `uvm_field_int(paddr,   UVM_ALL_ON)
    `uvm_field_int(pwdata,  UVM_ALL_ON)
    `uvm_field_int(pwrite,  UVM_ALL_ON)
    `uvm_field_int(rdata,   UVM_ALL_ON)
    `uvm_field_int(psel1,   UVM_ALL_ON)
    `uvm_field_int(psel2,   UVM_ALL_ON)
    `uvm_field_int(penable, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("addr=0x%03h wdata=0x%02h read=%0b | paddr=0x%03h pwdata=0x%02h pwrite=%0b rdata=0x%02h psel1=%0b psel2=%0b penable=%0b",
                     addr, wdata, read, paddr, pwdata, pwrite, rdata, psel1, psel2, penable);
  endfunction

endclass
