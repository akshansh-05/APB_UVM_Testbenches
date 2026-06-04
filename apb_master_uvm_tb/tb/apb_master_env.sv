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
  apb_master_agent      agent;       // Contains driver + monitor + sequencer
  apb_master_scoreboard scoreboard;  // Checks DUT behavior against expectations

  // ---- Constructor ----
  function new(string name = "apb_master_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase ----
  // Create the agent and scoreboard using the UVM factory.
  // type_id::create() uses the factory so that these components can be
  // overridden with derived classes if needed (e.g., for different tests).
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = apb_master_agent::type_id::create("agent", this);
    scoreboard = apb_master_scoreboard::type_id::create("scoreboard", this);
  endfunction

  // ---- Connect Phase ----
  // Wire the monitor's analysis port (ap) to the scoreboard's analysis
  // implementation port (analysis_export).
  //
  // Connection: agent.mon.ap ───→ scoreboard.analysis_export
  //
  // After this connection, every time the monitor calls ap.write(item),
  // the scoreboard's write() function is invoked automatically with
  // that item as the argument.
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(scoreboard.analysis_export);
  endfunction

endclass
