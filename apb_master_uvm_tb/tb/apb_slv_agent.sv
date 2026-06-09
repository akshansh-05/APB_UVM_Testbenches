// The reactive slave agent encapsulates the slave driver and monitor,
// responding to selection lines on the APB bus.
class apb_slv_agent extends uvm_agent;

  `uvm_component_utils(apb_slv_agent)

  apb_slv_driver    drv;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_slv_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = apb_slv_driver::type_id::create("drv", this);
  endfunction

endclass
