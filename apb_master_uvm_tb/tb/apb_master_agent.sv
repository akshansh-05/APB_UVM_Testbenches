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

  // =========================================================================
  // UVM PHASE: build_phase (Top-Down Execution)
  // =========================================================================
  // `build_phase` is used to instantiate sub-components. In UVM, it runs
  // TOP-DOWN through the component hierarchy:
  //   1. test.build_phase creates env
  //   2. env.build_phase creates agent
  //   3. agent.build_phase creates driver, monitor, and sequencer.
  //
  // This top-down flow is critical because parent components can configure
  // their child components (using `uvm_config_db`) before those children are built.
  //
  // ACTIVE vs. PASSIVE AGENTS:
  //   - Active: Generates stimulus. Creates sequencer + driver + monitor.
  //   - Passive: Observes bus. Creates only the monitor.
  //   - `get_is_active()` queries the UVM agent's built-in `is_active` variable.
  //     This can be set via `uvm_config_db` (e.g. from the test) to dynamically
  //     turn driving on/off without changing code.
  // =========================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // The monitor is passive, so it is always created (both active & passive modes).
    mon = apb_master_monitor::type_id::create("mon", this);

    // Instantiate driver and sequencer only if agent is active.
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_master_driver::type_id::create("drv", this);
      sqr = apb_master_sequencer::type_id::create("sqr", this);
    end
  endfunction

  // =========================================================================
  // UVM PHASE: connect_phase (Bottom-Up Execution)
  // =========================================================================
  // `connect_phase` runs after all components have been instantiated.
  // Unlike build_phase, it runs BOTTOM-UP.
  //
  // Here, we connect the TLM ports of the sub-components.
  // We connect the driver's `seq_item_port` (initiator) to the sequencer's
  // `seq_item_export` (target). This establishes the pull communication channel
  // through which the driver requests transactions from the sequencer.
  // =========================================================================
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass
