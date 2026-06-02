// ============================================================================
// FILE: apb_master_agent.sv
// DESCRIPTION:
//   Agent for the APB Master Bridge testbench.
//   Same structure as the slave TB agent — bundles driver, monitor, sequencer.
// ============================================================================

class apb_master_agent extends uvm_agent;

  `uvm_component_utils(apb_master_agent)

  // ---- Sub-components ----
  apb_master_driver    drv;
  apb_master_monitor   mon;
  apb_master_sequencer sqr;

  // ---- Constructor ----
  function new(string name = "apb_master_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase: Create sub-components ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always created
    mon = apb_master_monitor::type_id::create("mon", this);

    // Driver and Sequencer only in ACTIVE mode
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_master_driver::type_id::create("drv", this);
      sqr = apb_master_sequencer::type_id::create("sqr", this);
    end
  endfunction

  // ---- Connect Phase: Wire driver to sequencer ----
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass
