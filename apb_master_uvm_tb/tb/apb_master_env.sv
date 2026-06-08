// ============================================================================
// FILE: apb_master_env.sv
// DESCRIPTION:
//   Environment for the APB Master Bridge testbench.
//
//   The environment is the top-level UVM container that creates and wires
//   together all verification components:
//
//     ┌──────────────────── ENV ─────────────────────┐
//     │                                               │
//     │  ┌─────────────── AGENT ───────────────┐      │
//     │  │  Sequencer → Driver → DUT           │      │
//     │  │  Monitor ──────────────────────┐     │      │
//     │  └────────────────────────────────│─────┘      │
//     │                                   │            │
//     │                                   ↓            │
//     │  ┌─────────── SCOREBOARD ─────────────┐       │
//     │  │  Receives items, checks correctness │       │
//     │  └─────────────────────────────────────┘       │
//     └───────────────────────────────────────────────┘
//
//   The env doesn't do any protocol checking itself — it just creates
//   the agent and scoreboard, and wires the monitor's output to the
//   scoreboard's input.
// ============================================================================

// Extends uvm_env, which is a container component in the UVM hierarchy.
class apb_master_env extends uvm_env;

  // Register with UVM factory.
  `uvm_component_utils(apb_master_env)

  // ---- Sub-components ----
  apb_master_agent      agent;        // Contains driver + monitor + sequencer
  apb_master_scoreboard scoreboard;   // Checks DUT behavior against expectations
  apb_slave_driver      slave_driver; // Standalone Slave Driver (outside the agent)
  apb_memory_model      mem_model;    // Shared Memory Model (RAM storage)

  // ---- Constructor ----
  function new(string name = "apb_master_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  // UVM PHASE: build_phase
  // =========================================================================
  // In `build_phase`, the environment creates all of its child components.
  //
  // SHARING OBJECTS VIA LOCAL CONFIG_DB SCOPING:
  // We instantiate the `apb_memory_model` (a transaction-level RAM model)
  // and share it with both the `slave_driver` and the `scoreboard`.
  //
  //   uvm_config_db#(apb_memory_model)::set(this, "slave_driver", "mem_model", mem_model)
  //
  // Parameters Explained:
  //   1. context: We pass `this` (the environment component instance).
  //      This anchors the configuration lookup path to `uvm_test_top.env`.
  //   2. inst_name: We pass `"slave_driver"`. This restricts the scope of access
  //      strictly to the component named `slave_driver` inside `this` environment.
  //      No other component (e.g. agent monitor or sequencer) can retrieve it.
  //      This local scoping enforces strict encapsulation.
  //   3. field_name: `"mem_model"` is the lookup string.
  //   4. value: `mem_model` is the handle to the memory model instance.
  //
  // Why this decoupled design?
  //   By setting it in config_db, the `slave_driver` and `scoreboard` retrieve the
  //   shared memory block without having direct pointer variables to each other.
  //   This avoids circular dependencies in source compilation and prevents
  //   null pointer crashes if the scoreboard is disabled.
  // =========================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = apb_master_agent::type_id::create("agent", this);
    scoreboard = apb_master_scoreboard::type_id::create("scoreboard", this);
    
    // Create memory model (uvm_object) and slave driver (uvm_component)
    mem_model    = apb_memory_model::type_id::create("mem_model");
    slave_driver = apb_slave_driver::type_id::create("slave_driver", this);

    // Share memory model with slave driver and scoreboard using restricted scoping
    uvm_config_db #(apb_memory_model)::set(this, "slave_driver", "mem_model", mem_model);
    uvm_config_db #(apb_memory_model)::set(this, "scoreboard", "mem_model", mem_model);
  endfunction

  // ---- Connect Phase ----
  // Wire the monitor's analysis port to the scoreboard.
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(scoreboard.analysis_export);
  endfunction

endclass
