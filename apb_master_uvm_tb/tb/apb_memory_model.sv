// ============================================================================
// FILE: apb_memory_model.sv
// DESCRIPTION:
//   A UVM Object that models the memory space of the APB Slave.
//   This class wraps an associative array representing the RAM storage.
//   It is shared between the apb_slave_driver and the apb_master_scoreboard
//   via the uvm_config_db, ensuring clean separation of concerns.
//
//   UVM CONCEPTS DEMONSTRATED:
//     1. uvm_object:
//        Unlike uvm_component (which forms the static testbench hierarchy and 
//        runs through the build/connect/run phases), a uvm_object is a transient 
//        or configuration class. We extend uvm_object because this is a data 
//        structure (storage model) that is shared and passed around, not a 
//        hierarchical component of the testbench.
//     2. Protected Access:
//        The `protected` keyword ensures that the `ram` associative array 
//        cannot be directly modified from outside this class. Modification 
//        is only allowed via safe api methods: `write()` and `read_ram()`.
// ============================================================================

`ifndef APB_MEMORY_MODEL_SV
`define APB_MEMORY_MODEL_SV

class apb_memory_model extends uvm_object;

  // UVM Factory Registration:
  // Registers this class with the UVM factory so that it can be created using
  // `apb_memory_model::type_id::create()` instead of standard SystemVerilog `new()`.
  // Using the factory allows other developers to override this class with a derived
  // class (e.g., to inject errors or model different sizes) without modifying the env.
  `uvm_object_utils(apb_memory_model)

  // Internal RAM storage:
  // We use a SystemVerilog associative array mapping a 9-bit address key 
  // (matching the DUT address size) to an 8-bit data payload.
  // Associative arrays are sparse (allocated dynamically on-demand). 
  // This is highly efficient compared to a static array because we only consume
  // memory for addresses that are actually written to.
  protected bit [7:0] ram [bit [8:0]];

  // ---- Constructor ----
  // In SystemVerilog UVM, constructors of uvm_object take a single argument:
  // the string name of the object.
  function new(string name = "apb_memory_model");
    super.new(name); // Call the base class constructor
  endfunction

  // ---- Write Method ----
  // Performs a write operation, storing the byte of data at the specified address.
  // This is called by the slave driver when a write transaction completes on the APB bus.
  virtual function void write(bit [8:0] addr, bit [7:0] data);
    ram[addr] = data; // Insert/overwrite entry in associative array
    `uvm_info("MEM_MODEL", $sformatf("Memory Write: Addr=0x%03h, Data=0x%02h", addr, data), UVM_HIGH)
  endfunction

  // ---- Read RAM Method ----
  // Simulates a memory read operation.
  // - If the address exists, returns 1'b1 and updates the output argument `data`.
  // - If the address has never been written, returns 1'b0 (Read Miss).
  //
  // Use of `output` argument:
  // The method returns a boolean status (hit/miss) and uses the output argument
  // to return the read value, allowing the caller to safely detect uninitialized reads.
  virtual function bit read_ram(bit [8:0] addr, output bit [7:0] data);
    // `.exists()` is a SystemVerilog associative array method.
    // It checks if a key (addr) has an allocated entry in the array.
    if (ram.exists(addr)) begin
      data = ram[addr]; // Retrieve the stored data
      `uvm_info("MEM_MODEL", $sformatf("Memory Read Hit: Addr=0x%03h, Data=0x%02h", addr, data), UVM_HIGH)
      return 1'b1;      // Read success
    end
    else begin
      `uvm_info("MEM_MODEL", $sformatf("Memory Read Miss: Addr=0x%03h (Address never written)", addr), UVM_HIGH)
      return 1'b0;      // Read miss
    end
  endfunction

  // ---- Clear Memory ----
  // Clears all elements from the associative array, resetting the memory state.
  virtual function void clear();
    ram.delete(); // built-in method to delete all elements in an associative array
  endfunction

endclass

`endif // APB_MEMORY_MODEL_SV
