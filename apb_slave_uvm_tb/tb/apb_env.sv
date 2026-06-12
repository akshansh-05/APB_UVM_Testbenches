`include "uvm_macros.svh"
import uvm_pkg::*;

//   The same Env can be reused across many different tests.

// The UVM environment container class groups and instantiates all sub-components:
// - sys_agent: system-side active agent driving host requests
// - slv_agent: reactive slave agent modeling memory responses
// - monitor: standalone APB bus-side monitor
// - scoreboard: checks data compliance, select routing, and handshakes
class apb_env extends uvm_env;

  `uvm_component_utils(apb_env)

  apb_agent      agent;
  apb_scoreboard scoreboard;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_env", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = apb_agent::type_id::create("agent", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
  endfunction

    // Connect Phase: wire TLM analysis ports, exports, and sequencer interfaces together
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    agent.mon.ap.connect(scoreboard.analysis_export);
  endfunction

endclass
