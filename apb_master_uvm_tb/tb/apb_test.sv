// ============================================================================
// FILE: apb_test.sv
// DESCRIPTION: UVM base and concrete test cases for APB Master TB
// ============================================================================

class test_apb_base extends uvm_test;                     // Extends base class for all UVM tests

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(test_apb_base)                     // Registers base test class with factory

  // ---- SUB-COMPONENTS ----
  apb_env env;                                            // Handle to environment container class

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "test_apb_base", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls parent base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM BUILD PHASE ----
  function void build_phase(uvm_phase phase);            // Build phase callback
    super.build_phase(phase);                            // Calls parent build phase
    env = apb_env::type_id::create("env", this);          // Instantiates environment container class object via factory
  endfunction                                            // End of build phase declaration

endclass // End of test_apb_base class declaration


class apb_master_test extends test_apb_base;              // Extends the custom base test class

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(apb_master_test)                   // Registers concrete test class with factory

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_master_test", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM RUN PHASE ----
  task run_phase(uvm_phase phase);                       // Run phase time-consuming task
    apb_write_read_seq seq;                              // Handle for write-read test sequence

    phase.raise_objection(this);                         // Raises objection to prevent premature test termination

    `uvm_info("TEST", "================================================", UVM_LOW) // Prints startup banner line
    `uvm_info("TEST", "  APB Master Bridge UVM Test Starting", UVM_LOW)           // Prints startup message
    `uvm_info("TEST", "================================================", UVM_LOW) // Prints startup banner footer

    #100ns;                                              // Wait 100ns to let reset clear completely

    seq = apb_write_read_seq::type_id::create("seq");    // Instantiates test sequence via factory
    seq.start(env.sys_agent.sqr);                        // Starts sequence on system-side sequencer

    #100ns;                                              // Wait 100ns post-activity for bus signals to settle

    `uvm_info("TEST", "================================================", UVM_LOW) // Prints shutdown banner line
    `uvm_info("TEST", "  APB Master Bridge UVM Test Complete", UVM_LOW)          // Prints shutdown message
    `uvm_info("TEST", "================================================", UVM_LOW) // Prints shutdown banner footer

    phase.drop_objection(this);                          // Drops objection to allow test to end clean
  endtask                                                // End of run phase task declaration

endclass // End of apb_master_test class declaration
