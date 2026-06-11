// =============================================================================
// FILE: apb_seq_item.sv
// DESCRIPTION:
//   APB Sequence Item — the fundamental data container representing a single
//   APB transaction flowing through the UVM testbench.
//
//   This class carries TWO categories of fields:
//     1. STIMULUS fields (addr, wdata, read) — randomized by sequences,
//        consumed by the system driver to drive DUT inputs.
//     2. RESPONSE/MONITOR fields (paddr, pwdata, pwrite, rdata, psel1, psel2,
//        penable, pslverr) — populated by monitors after sampling physical
//        bus signals, and consumed by the scoreboard for checking.
//
//   The separation of stimulus vs. response fields allows the same packet type
//   to flow through the entire testbench: sequence → driver → DUT → monitor → scoreboard.
//
//   RANDOMIZATION:
//     The 'rand' qualifier on addr, wdata, and read allows the UVM constraint
//     solver to generate random stimulus. Sequences can apply inline constraints
//     (e.g., `randomize() with { read == 0; }`) to direct specific scenarios.
//
//   FIELD AUTOMATION:
//     The `uvm_field_int` macros auto-generate copy(), compare(), print(),
//     pack(), and unpack() methods, eliminating boilerplate code.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_seq_item extends uvm_sequence_item;

  // ---------------------------------------------------------------------------
  // STIMULUS FIELDS — set by sequences, read by system driver
  // These fields represent the "command" that the system sends to the master DUT.
  // ---------------------------------------------------------------------------
  rand bit [8:0] addr;    // 9-bit address: bit[8] selects slave (0=Slave1, 1=Slave2),
                          //                bits[7:0] are the memory offset within that slave
  rand bit [7:0] wdata;   // 8-bit write data payload to be written to the target address
  rand bit       read;    // Transfer direction flag: 0=Write, 1=Read
                          // Maps to DUT input READ_WRITE (0=write, 1=read)

  // ---------------------------------------------------------------------------
  // RESPONSE/MONITOR FIELDS — populated by monitors after observing the bus
  // These fields capture what actually happened on the APB bus, for scoreboard comparison.
  // ---------------------------------------------------------------------------
  bit [8:0] paddr;     // Actual PADDR observed on the APB bus by the bus monitor
  bit [7:0] pwdata;    // Actual PWDATA observed on the APB bus during write transfers
  bit       pwrite;    // Actual PWRITE observed: 1=write, 0=read (inverse of 'read')
  bit [7:0] rdata;     // Read data: captured from PRDATA (bus monitor) or apb_read_data_out (sys monitor)
  bit       psel1;     // Actual PSEL1 state observed — should be 1 when PADDR[8]=0
  bit       psel2;     // Actual PSEL2 state observed — should be 1 when PADDR[8]=1
  bit       penable;   // Actual PENABLE state — should be 1 during ACCESS phase handshake
  bit       pslverr;   // Actual PSLVERR state — should be 0 for normal operation

  // ---------------------------------------------------------------------------
  // CONSTRAINT: Limit address to valid 9-bit range (0x000 to 0x1FF)
  // ---------------------------------------------------------------------------
  constraint c_valid_addr { addr inside {[0:511]}; }

  // ---------------------------------------------------------------------------
  // FIELD AUTOMATION — register all fields for automatic copy/compare/print
  // UVM_ALL_ON enables all field operations (copy, compare, print, pack, etc.)
  // ---------------------------------------------------------------------------
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
    `uvm_field_int(pslverr, UVM_ALL_ON)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // Standard UVM object constructor with default name for factory creation.
  // ---------------------------------------------------------------------------
  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  // CONVERT2STRING
  // Returns a human-readable formatted string of all transaction fields.
  // Used by UVM's print/sprint methods and for debug log messages.
  // Format: stimulus fields | response fields
  // ---------------------------------------------------------------------------
  virtual function string convert2string();
    return $sformatf("addr=0x%03h wdata=0x%02h read=%0b | paddr=0x%03h pwdata=0x%02h pwrite=%0b rdata=0x%02h psel1=%0b psel2=%0b penable=%0b pslverr=%0b",
                     addr, wdata, read, paddr, pwdata, pwrite, rdata, psel1, psel2, penable, pslverr);
  endfunction

endclass
