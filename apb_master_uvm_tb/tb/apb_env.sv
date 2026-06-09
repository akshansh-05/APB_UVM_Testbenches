// The UVM environment container class groups and instantiates all sub-components:
// - sys_agent: system-side active agent driving host requests
// - slv_agent: reactive slave agent modeling memory responses
// - monitor: standalone APB bus-side monitor
// - scoreboard: checks data compliance, select routing, and handshakes
class apb_env extends uvm_env;

  `uvm_component_utils(apb_env)

  apb_sys_agent    sys_agent;
  apb_slv_agent    slv_agent;
  apb_monitor      monitor;
  apb_scoreboard   scoreboard;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_env", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sys_agent  = apb_sys_agent::type_id::create("sys_agent", this);
    slv_agent  = apb_slv_agent::type_id::create("slv_agent", this);
    monitor    = apb_monitor::type_id::create("monitor", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
  endfunction

    // Connect Phase: wire TLM analysis ports, exports, and sequencer interfaces together
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    sys_agent.mon.ap.connect(scoreboard.exp_port);
    monitor.ap.connect(scoreboard.act_port);
  endfunction

endclass
