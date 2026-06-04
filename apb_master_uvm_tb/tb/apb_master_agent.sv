// ============================================================================
// FILE: apb_master_agent.sv
// DESCRIPTION:
//   Agent for the APB Master Bridge testbench.
//
//   An agent bundles three components together:
//     ┌──────────────────────────────────────────────┐
//     │                   AGENT                       │
//     │                                               │
//     │  ┌───────────┐   ┌───────────┐                │
//     │  │ Sequencer │──→│  Driver   │──→ DUT         │
//     │  └───────────┘   └───────────┘                │
//     │                                               │
//     │  ┌───────────┐                                │
//     │  │  Monitor  │──→ analysis port → Scoreboard  │
//     │  └───────────┘                                │
//     └──────────────────────────────────────────────┘
//
//   ACTIVE vs PASSIVE MODE:
//   - UVM_ACTIVE (default):  Creates driver + sequencer + monitor.
//     The agent can both drive and observe.
//   - UVM_PASSIVE: Creates only the monitor.
//     The agent can only observe (useful for protocol checkers).
//
//   The agent's is_active mode is set via uvm_config_db or defaults.
// ============================================================================

// Extends uvm_agent, which provides the is_active infrastructure.
class apb_master_agent extends uvm_agent;

  // Register with UVM factory.
  `uvm_component_utils(apb_master_agent)

  // ---- Sub-components ----
  // These are handles (pointers) to the child components.
  // They are created in build_phase based on the agent's active/passive mode.
  apb_master_driver    drv;   // Drives system-side signals into the DUT
  apb_master_monitor   mon;   // Passively observes APB bus signals from the DUT
  apb_master_sequencer sqr;   // Queues transactions between sequences and driver

  // ---- Constructor ----
  function new(string name = "apb_master_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase: Create sub-components ----
  // build_phase runs top-down in the UVM hierarchy.
  // The agent creates its children here.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is ALWAYS created — we always want to observe.
    mon = apb_master_monitor::type_id::create("mon", this);

    // Driver and Sequencer are only created in ACTIVE mode.
    // In PASSIVE mode, the agent only monitors (no driving).
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_master_driver::type_id::create("drv", this);
      sqr = apb_master_sequencer::type_id::create("sqr", this);
    end
  endfunction

  // ---- Connect Phase: Wire driver to sequencer ----
  // connect_phase runs bottom-up. We connect the TLM ports here.
  // The driver's seq_item_port is connected to the sequencer's seq_item_export.
  // This creates the communication channel:
  //   Sequence → Sequencer (seq_item_export) → Driver (seq_item_port)
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass
