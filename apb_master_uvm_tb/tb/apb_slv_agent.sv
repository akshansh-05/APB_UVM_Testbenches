// ============================================================================
// FILE: apb_slv_agent.sv
// DESCRIPTION: Reactive slave-side agent for the APB Master TB
// ============================================================================

class apb_slv_agent extends uvm_agent;                  // Extends standard UVM agent base class

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(apb_slv_agent)                   // Registers class with factory

  // ---- SUB-COMPONENTS ----
  apb_slv_driver    drv;                                 // Reactive slave driver handle

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_slv_agent", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls parent base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM BUILD PHASE ----
  function void build_phase(uvm_phase phase);            // Build phase callback
    super.build_phase(phase);                            // Calls parent build phase
    drv = apb_slv_driver::type_id::create("drv", this);  // Instantiates reactive slave driver via factory
  endfunction                                            // End of build phase declaration

endclass // End of apb_slv_agent class declaration
