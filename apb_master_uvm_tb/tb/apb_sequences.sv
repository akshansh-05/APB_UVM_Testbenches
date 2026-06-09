// ============================================================================
// FILE: apb_sequences.sv
// DESCRIPTION: Test sequences for the APB Master testbench.
// ============================================================================

class apb_write_read_seq extends uvm_sequence #(apb_seq_item); // Extends standard uvm_sequence parameterized with apb_seq_item

  // ---- UVM FACTORY REGISTER ----
  `uvm_object_utils(apb_write_read_seq)                  // Registers class with factory

  // ---- LOCAL VARIABLES TO REMEMBER THE TRANSFER ----
  bit [8:0] target_addr;                                 // Storage variable for generated write address
  bit [7:0] target_wdata;                                // Storage variable for generated write data

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_write_read_seq");      // Constructor taking name argument
    super.new(name);                                     // Calls parent base class constructor
  endfunction                                            // End of constructor declaration

  // ---- SEQUENCE BODY TASK ----
  task body();                                           // Body task where sequence logic runs
    apb_seq_item write_item;                             // Handle for write transaction packet
    apb_seq_item read_item;                              // Handle for read transaction packet

    `uvm_info("SEQ", "Starting simplified WRITE-READ sequence", UVM_MEDIUM) // Logs startup message

    // ── Phase 1: Write Transaction ──
    write_item = apb_seq_item::type_id::create("write_item"); // Instantiates write transaction item via factory
    start_item(write_item);                               // Blocks until sequencer allows generation
    if (!write_item.randomize() with {                   // Randomizes item with inline constraints
      read == 1'b0;                                      // Constrains transaction to be a write request
      addr[8] == 1'b0;                                   // Targets Slave 1 (address bit 8 is low)
      addr[7:0] == 8'h10;                                // Target address offset is set to 0x10
      wdata == 8'hBE;                                    // Targets data payload is set to 0xBE
    }) begin                                             // Handles randomization failure
      `uvm_error("SEQ", "Write randomization failed!")   // Reports failure to console
    end                                                  // End of write randomization block

    target_addr  = write_item.addr;                      // Saves the write address locally
    target_wdata = write_item.wdata;                     // Saves the write data locally

    `uvm_info("SEQ", $sformatf("Sending Write: Addr=0x%03h, Data=0x%02h", write_item.addr, write_item.wdata), UVM_MEDIUM) // Logs write details

    finish_item(write_item);                             // Sends write transaction item to driver and blocks until completion

    // ── Phase 2: Read Transaction ──
    read_item = apb_seq_item::type_id::create("read_item"); // Instantiates read transaction item via factory
    start_item(read_item);                               // Blocks until sequencer allows generation
    if (!read_item.randomize() with {                    // Randomizes item with inline constraints
      read == 1'b1;                                      // Constrains transaction to be a read request
      addr == target_addr;                               // Forces read from the exact address written previously
    }) begin                                             // Handles randomization failure
      `uvm_error("SEQ", "Read randomization failed!")    // Reports failure to console
    end                                                  // End of read randomization block

    `uvm_info("SEQ", $sformatf("Sending Read: Addr=0x%03h", read_item.addr), UVM_MEDIUM) // Logs read details

    finish_item(read_item);                              // Sends read transaction item to driver and blocks until completion

    `uvm_info("SEQ", $sformatf("Read Completed: Addr=0x%03h, Expected Data=0x%02h, Got Data=0x%02h", read_item.addr, target_wdata, read_item.rdata), UVM_MEDIUM) // Logs read results

    `uvm_info("SEQ", "WRITE-READ sequence complete", UVM_MEDIUM) // Logs completion message
  endtask                                                // End of body task declaration

endclass // End of apb_write_read_seq class declaration
