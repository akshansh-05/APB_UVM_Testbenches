`include "uvm_macros.svh"
import uvm_pkg::*;

//   The Agent is a container that bundles together:
//   had multiple APB ports, you'd have one Agent per port.

// The agent bundles the driver, sequencer, and monitor for the APB Slave DUT.
// It runs in ACTIVE mode to generate and drive stimulus.
class apb_agent extends uvm_agent;

  `uvm_component_utils(apb_agent)

  apb_driver    drv;
  apb_monitor   mon;
  apb_sequencer sqr;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mon = apb_monitor::type_id::create("mon", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

    // Connect Phase: wire TLM analysis ports, exports, and sequencer interfaces together
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass
