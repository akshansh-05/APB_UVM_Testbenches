// =============================================================================
// FILE: apb_env.sv
// DESCRIPTION:
//   APB Environment — the top-level UVM container that groups and wires together
//   ALL verification sub-components.
//
//   COMPONENT HIERARCHY (created in build_phase):
//     apb_env
//     ├── sys_agent   (apb_sys_agent)  — ACTIVE agent: drives system-side inputs
//     │   ├── drv     (apb_sys_driver) — Drives transfer, address, data to DUT
//     │   ├── sqr     (apb_sequencer)  — Feeds transactions from sequences
//     │   └── mon     (apb_sys_monitor)— Captures expected transactions
//     ├── slv_agent   (apb_slv_agent)  — REACTIVE agent: emulates slave responses
//     │   └── drv     (apb_slv_driver) — Responds with PREADY, PRDATA
//     ├── monitor     (apb_monitor)    — Standalone bus monitor: captures actual transactions
//     └── scoreboard  (apb_scoreboard) — Checker: compares expected vs actual
//
//   TLM CONNECTIONS (created in connect_phase):
//     sys_agent.mon.ap  ──→  scoreboard.exp_port  (expected transactions)
//     monitor.ap        ──→  scoreboard.act_port  (actual transactions)
//
//   This wiring ensures the scoreboard receives:
//     1. What the system REQUESTED (from sys_monitor) — pushed to expected queue
//     2. What ACTUALLY HAPPENED on the bus (from bus monitor) — triggers comparison
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_env extends uvm_env;

  `uvm_component_utils(apb_env)    // Register with UVM factory

  // ---------------------------------------------------------------------------
  // SUB-COMPONENTS
  // ---------------------------------------------------------------------------
  apb_sys_agent    sys_agent;     // Active agent: drives system-side DUT inputs
  apb_slv_agent    slv_agent;     // Reactive agent: emulates slave on APB bus
  apb_monitor      monitor;       // Standalone bus monitor: observes APB handshakes
  apb_scoreboard   scoreboard;    // Checker: verifies correctness of all transfers

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE — instantiate all sub-components
  // All components are created via the UVM factory (type_id::create) to allow
  // type overrides in tests if needed.
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sys_agent  = apb_sys_agent::type_id::create("sys_agent", this);
    slv_agent  = apb_slv_agent::type_id::create("slv_agent", this);
    monitor    = apb_monitor::type_id::create("monitor", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  // ---------------------------------------------------------------------------
  // CONNECT PHASE — wire TLM analysis ports between monitors and scoreboard
  //
  // Connection 1: sys_agent.mon.ap → scoreboard.exp_port
  //   The system monitor captures what was REQUESTED and sends it as the
  //   expected reference for scoreboard comparison.
  //
  // Connection 2: monitor.ap → scoreboard.act_port
  //   The bus monitor captures what ACTUALLY HAPPENED on the APB bus and
  //   sends it to the scoreboard for comparison against expected.
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    sys_agent.mon.ap.connect(scoreboard.exp_port);    // Expected transactions
    monitor.ap.connect(scoreboard.act_port);           // Actual transactions
  endfunction

endclass
