// ============================================================================
// FILE: apb_sys_agent.sv
// DESCRIPTION: Active system-side agent for the APB Master TB
// ============================================================================

class apb_sys_agent extends uvm_agent;                  // Extends the standard UVM agent base class

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(apb_sys_agent)                   // Registers the agent class with factory

  // ---- SUB-COMPONENTS ----
  apb_sys_driver    drv;                                 // Handle for active system driver
  apb_sys_monitor   mon;                                 // Handle for passive system monitor
  apb_sequencer     sqr;                                 // Handle for transaction sequencer

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_sys_agent", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls parent base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM BUILD PHASE ----
  function void build_phase(uvm_phase phase);            // Build phase callback
    super.build_phase(phase);                            // Calls parent build phase

    mon = apb_sys_monitor::type_id::create("mon", this); // Always instantiates system monitor (active & passive)

    if (get_is_active() == UVM_ACTIVE) begin             // Checks if the agent is configured as active
      drv = apb_sys_driver::type_id::create("drv", this); // Instantiates system driver object via factory
      sqr = apb_sequencer::type_id::create("sqr", this);  // Instantiates sequencer object via factory
    end                                                  // End of active mode instantiation block
  endfunction                                            // End of build phase declaration

  // ---- UVM CONNECT PHASE ----
  function void connect_phase(uvm_phase phase);          // Connect phase callback
    super.connect_phase(phase);                          // Calls parent connect phase
    if (get_is_active() == UVM_ACTIVE) begin             // Checks if agent is in active mode
      drv.seq_item_port.connect(sqr.seq_item_export);    // Connects driver sequencer port to sequencer export
    end                                                  // End of active mode connection block
  endfunction                                            // End of connect phase declaration

endclass // End of apb_sys_agent class declaration
