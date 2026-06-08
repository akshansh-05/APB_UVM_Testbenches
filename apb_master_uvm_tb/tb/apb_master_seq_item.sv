// ============================================================================
// FILE: apb_master_seq_item.sv
// DESCRIPTION:
//   Transaction class for the APB Master Bridge testbench.
//
//   A "sequence item" (also called a "transaction") is the fundamental data
//   object that flows through the UVM testbench:
//     Sequence → Sequencer → Driver → DUT
//                                       ↓
//                           Monitor → Scoreboard
//
//   This item serves TWO roles:
//     1. DRIVER uses it to know WHAT transfer to request
//        (addr, wdata, read fields are randomized by the sequence)
//     2. MONITOR uses it to record WHAT actually happened on the APB bus
//        (paddr, pwdata, pwrite, rdata, psel1, psel2, pslverr are captured)
//
//   The Scoreboard then uses the monitored fields to check correctness.
// ============================================================================

// =========================================================================
// UVM CONCEPT: uvm_sequence_item vs. uvm_component
// =========================================================================
// In UVM, there are two primary base classes:
//   1. uvm_component: Static testbench components (drivers, monitors, envs)
//      that are created once at the beginning of the simulation (in build_phase),
//      remain in memory, and execute phases (build, connect, run, etc.).
//   2. uvm_object: Dynamic, transient objects (transactions, configurations)
//      that are created dynamically during simulation, used, and then garbage
//      collected by the SystemVerilog runtime.
//
// `uvm_sequence_item` extends `uvm_object`. It does NOT have phases because
// it is a data container, not a structural component. It represents a single
// packet or transaction (e.g. an APB read/write bus transaction).
// =========================================================================
class apb_master_seq_item extends uvm_sequence_item;

  // ===================== DRIVER FIELDS =====================
  // These are the fields that the SEQUENCE randomizes and the DRIVER reads.
  // They represent what the system side wants to do.
  // "rand" means these fields will be randomized when item.randomize() is called.
  // "bit" is a 2-state type (0 or 1), which is fine for synthesizable data.

  rand bit [8:0] addr;    // 9-bit address: bit[8] selects slave (0→Slave1, 1→Slave2)
                           //                bits[7:0] are the actual address within the slave
  rand bit [7:0] wdata;   // 8-bit data to write (only meaningful for write transactions)
  rand bit       read;    // Transaction direction: 1 = read, 0 = write

  // ===================== MONITOR FIELDS =====================
  // These are filled in by the MONITOR after observing the APB bus.
  // They are NOT randomized — they capture what the DUT actually did.
  // The scoreboard compares these against expected values.

  bit [8:0] paddr;              // Observed PADDR on APB bus (should match addr)
  bit [7:0] pwdata;             // Observed PWDATA on APB bus (should match wdata for writes)
  bit       pwrite;             // Observed PWRITE signal (1=write, 0=read)
  bit [7:0] rdata;              // Observed apb_read_data_out (read data from slave)
  bit       psel1;              // Observed PSEL1 (should be 1 when paddr[8]=0)
  bit       psel2;              // Observed PSEL2 (should be 1 when paddr[8]=1)
  bit       penable;            // Observed PENABLE (should be 1 during ACCESS phase)
  bit       pslverr;            // Observed PSLVERR (should be 0 for valid transfers)

  // ===================== CONSTRAINTS =====================
  // Constraints guide the randomizer to produce valid values.
  // addr is 9 bits, so max value is 511 (0x1FF). This constraint ensures
  // we stay within the valid address space. Both slaves have 256 addresses each.
  constraint c_valid_addr { addr inside {[0:511]}; }

  // =========================================================================
  // UVM FACTORY & FIELD MACROS
  // =========================================================================
  // `uvm_object_utils_begin(apb_master_seq_item) and `uvm_object_utils_end
  // register the class with the UVM Factory and open a block for field automation.
  //
  // Factory Registration:
  //   Enables type override capability (e.g. replacing apb_master_seq_item with
  //   an error_injecting_seq_item at run-time without changing component source code).
  //
  // Field Automation Macros (`uvm_field_int):
  //   UVM provides macros like `uvm_field_int`, `uvm_field_string`, etc.
  //   These automatically implement several core methods of `uvm_object`:
  //     - copy(): Performs a deep copy of all registered fields.
  //     - compare(): Performs field-by-field comparisons between two transactions.
  //     - print()/sprint(): Formats and prints all fields as a table or string.
  //     - pack()/unpack(): Serializes fields into a bit array (useful for network
  //       or physical protocols) and deserializes them back.
  //
  //   `UVM_ALL_ON` tells the macro to enable all these features for this field.
  //   While field macros make code very concise, they can add simulation overhead.
  //   For complex systems, verification engineers sometimes write custom copy/compare
  //   methods for maximum speed. For most testbenches, the macros are preferred.
  // =========================================================================
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
    `uvm_field_int(penable, UVM_ALL_ON)
    `uvm_field_int(pslverr, UVM_ALL_ON)
  `uvm_object_utils_end

  // ---- Constructor ----
  // Every UVM object needs a constructor with a default name.
  // "super.new(name)" calls the parent class constructor to set the object name.
  function new(string name = "apb_master_seq_item");
    super.new(name);
  endfunction

  // ---- convert2string ----
  // Returns a human-readable one-line summary of this transaction.
  // Called by `uvm_info when you do: `uvm_info("TAG", item.convert2string(), ...)
  // "virtual" keyword is required because it overrides the base class method
  // uvm_object::convert2string(), which is declared virtual. Without "virtual"
  // here, polymorphic calls would call the base class version instead.
  virtual function string convert2string();
    return $sformatf("addr=0x%03h wdata=0x%02h read=%0b | paddr=0x%03h pwdata=0x%02h pwrite=%0b rdata=0x%02h psel1=%0b psel2=%0b penable=%0b pslverr=%0b",
                     addr, wdata, read, paddr, pwdata, pwrite, rdata, psel1, psel2, penable, pslverr);
  endfunction

endclass
