// ============================================================================
// FILE: apb_agent.sv
// DESCRIPTION:
//   The Agent is a container that bundles together:
//     - Driver    (drives signals to the DUT)
//     - Monitor   (observes signals from the DUT)
//     - Sequencer (queues transactions for the driver)
//
//   WHY AN AGENT?
//   -------------
//   In UVM, an Agent represents one "interface" to the DUT. If your DUT
//   had multiple APB ports, you'd have one Agent per port.
//
//   ACTIVE vs PASSIVE:
//   - ACTIVE agent: Has a driver + sequencer (drives stimulus)
//   - PASSIVE agent: Has only a monitor (just watches)
//   We use ACTIVE mode here because we need to drive transactions.
// ============================================================================

class apb_agent extends uvm_agent;

  `uvm_component_utils(apb_agent)

  // ---- Sub-components ----
  apb_driver    drv;
  apb_monitor   mon;
  apb_sequencer sqr;

  // ---- Constructor ----
  function new(string name = "apb_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase: Create sub-components ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is ALWAYS created (active or passive agent)
    mon = apb_monitor::type_id::create("mon", this);

    // Driver and Sequencer are only created in ACTIVE mode
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  // ---- Connect Phase: Wire up the driver to the sequencer ----
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (get_is_active() == UVM_ACTIVE) begin
      // Connect driver's "pull port" to sequencer's "export port"
      // This is how the driver pulls items from the sequencer.
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass
