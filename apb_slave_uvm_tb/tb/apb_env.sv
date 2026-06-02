// ============================================================================
// FILE: apb_env.sv
// DESCRIPTION:
//   The Environment is the top-level UVM container that holds all
//   verification components together:
//     - Agent (which contains driver, monitor, sequencer)
//     - Scoreboard (which checks correctness)
//
//   WHY AN ENVIRONMENT?
//   -------------------
//   It provides a clean separation between the TEST (which defines
//   WHAT to test) and the ENV (which defines HOW to verify).
//   The same Env can be reused across many different tests.
// ============================================================================

class apb_env extends uvm_env;

  `uvm_component_utils(apb_env)

  // ---- Sub-components ----
  apb_agent      agent;
  apb_scoreboard scoreboard;

  // ---- Constructor ----
  function new(string name = "apb_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase: Create agent and scoreboard ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = apb_agent::type_id::create("agent", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  // ---- Connect Phase: Wire monitor's output to scoreboard's input ----
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect the monitor's analysis port to the scoreboard
    // Now every transaction the monitor sees will be sent to the scoreboard.
    agent.mon.ap.connect(scoreboard.analysis_export);
  endfunction

endclass
