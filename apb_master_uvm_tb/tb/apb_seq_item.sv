// ============================================================================
// FILE: apb_seq_item.sv
// DESCRIPTION: Transaction class for the APB Master Bridge testbench.
// ============================================================================

class apb_seq_item extends uvm_sequence_item;                 // Extends the UVM base sequence item class

  // ---- DRIVER FIELD MEMBERS (Randomized by Sequences) ----
  rand bit [8:0] addr;                                        // 9-bit randomized address; bit[8] selects slave, bits[7:0] target offset
  rand bit [7:0] wdata;                                       // 8-bit randomized data to write during write transfers
  rand bit       read;                                        // 1-bit direction flag: 1 for Read transfers, 0 for Write transfers

  // ---- MONITOR FIELD MEMBERS (Observed from APB Bus) ----
  bit [8:0] paddr;                                            // 9-bit address observed directly on the APB bus
  bit [7:0] pwdata;                                           // 8-bit write data observed directly on the APB bus
  bit       pwrite;                                           // 1-bit write direction flag observed directly on the APB bus
  bit [7:0] rdata;                                            // 8-bit read data observed directly on the APB bus
  bit       psel1;                                            // Chip select for Slave 1 observed directly on the APB bus
  bit       psel2;                                            // Chip select for Slave 2 observed directly on the APB bus
  bit       penable;                                          // Strobe signal indicating Access phase observed on the APB bus
  bit       pslverr;                                          // Error status flag observed directly on the APB bus

  // ---- CONSTRAINTS ----
  constraint c_valid_addr { addr inside {[0:511]}; }          // Address must reside within 512-byte address space

  // ---- UVM FACTORY REGISTER WITH AUTOMATION FIELD MACROS ----
  `uvm_object_utils_begin(apb_seq_item)                       // Begin of field registration macro block
    `uvm_field_int(addr,    UVM_ALL_ON)                       // Registers system address with UVM methods
    `uvm_field_int(wdata,   UVM_ALL_ON)                       // Registers system write data with UVM methods
    `uvm_field_int(read,    UVM_ALL_ON)                       // Registers system read/write direction
    `uvm_field_int(paddr,   UVM_ALL_ON)                       // Registers observed APB bus address
    `uvm_field_int(pwdata,  UVM_ALL_ON)                       // Registers observed APB bus write data
    `uvm_field_int(pwrite,  UVM_ALL_ON)                       // Registers observed APB bus direction flag
    `uvm_field_int(rdata,   UVM_ALL_ON)                       // Registers observed APB bus read data
    `uvm_field_int(psel1,   UVM_ALL_ON)                       // Registers observed APB Slave 1 select
    `uvm_field_int(psel2,   UVM_ALL_ON)                       // Registers observed APB Slave 2 select
    `uvm_field_int(penable, UVM_ALL_ON)                       // Registers observed APB bus enable signal
    `uvm_field_int(pslverr, UVM_ALL_ON)                       // Registers observed APB bus error feedback
  `uvm_object_utils_end                                       // End of field registration macro block

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_seq_item");                 // UVM object constructor taking name argument
    super.new(name);                                          // Calls base class constructor with name argument
  endfunction                                                 // End of constructor declaration

  // ---- HELPER METHOD TO PRINT TRANSACTION DETAILS ----
  virtual function string convert2string();                   // Overrides virtual base method convert2string
    return $sformatf("addr=0x%03h wdata=0x%02h read=%0b | paddr=0x%03h pwdata=0x%02h pwrite=%0b rdata=0x%02h psel1=%0b psel2=%0b penable=%0b pslverr=%0b", // Formats member variables into a single line string
                     addr, wdata, read, paddr, pwdata, pwrite, rdata, psel1, psel2, penable, pslverr); // Passes all signal values to $sformatf
  endfunction                                                 // End of convert2string function declaration

endclass // End of apb_seq_item class declaration
