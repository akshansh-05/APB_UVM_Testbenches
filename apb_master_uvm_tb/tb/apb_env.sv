// ============================================================================
// FILE: apb_env.sv
// DESCRIPTION: UVM environment class for wiring agents, monitor and scoreboard
// ============================================================================

class apb_env extends uvm_env;                            // Extends the standard UVM environment base class

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(apb_env)                           // Registers environment class with UVM factory

  // ---- SUB-COMPONENTS ----
  apb_sys_agent    sys_agent;                             // System-side active agent instance handle
  apb_slv_agent    slv_agent;                             // Slave-side reactive agent instance handle
  apb_monitor      monitor;                               // Standalone APB bus monitor instance handle
  apb_scoreboard   scoreboard;                            // Checking scoreboard instance handle

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_env", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls parent base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM BUILD PHASE ----
  function void build_phase(uvm_phase phase);            // Build phase callback
    super.build_phase(phase);                            // Calls parent build phase
    sys_agent  = apb_sys_agent::type_id::create("sys_agent", this);  // Instantiates system-side agent via factory
    slv_agent  = apb_slv_agent::type_id::create("slv_agent", this);  // Instantiates slave-side agent via factory
    monitor    = apb_monitor::type_id::create("monitor", this);      // Instantiates standalone monitor via factory
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);// Instantiates checker scoreboard via factory
  endfunction                                            // End of build phase declaration

  // ---- UVM CONNECT PHASE ----
  function void connect_phase(uvm_phase phase);          // Connect phase callback
    super.connect_phase(phase);                          // Calls parent connect phase
    sys_agent.mon.ap.connect(scoreboard.exp_port);       // Wires system monitor's expected port to scoreboard exp_port
    monitor.ap.connect(scoreboard.act_port);             // Wires standalone monitor's actual port to scoreboard act_port
  endfunction                                            // End of connect phase declaration

endclass // End of apb_env class declaration
