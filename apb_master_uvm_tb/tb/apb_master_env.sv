// ============================================================================
// FILE: apb_master_env.sv
// DESCRIPTION:
//   Environment for the APB Master Bridge testbench.
//   Creates agent + scoreboard and wires them together.
//   Same pattern as the slave TB environment.
// ============================================================================

class apb_master_env extends uvm_env;

  `uvm_component_utils(apb_master_env)

  // ---- Sub-components ----
  apb_master_agent      agent;
  apb_master_scoreboard scoreboard;

  // ---- Constructor ----
  function new(string name = "apb_master_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = apb_master_agent::type_id::create("agent", this);
    scoreboard = apb_master_scoreboard::type_id::create("scoreboard", this);
  endfunction

  // ---- Connect Phase ----
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Wire monitor → scoreboard
    agent.mon.ap.connect(scoreboard.analysis_export);
  endfunction

endclass
