// =============================================================================
// FILE: apb_sys_agent.sv
// DESCRIPTION:
//   APB System Agent — the ACTIVE agent on the system/host side of the DUT.
//
//   This agent groups three sub-components that together handle the system-side
//   interaction with the APB Master Bridge DUT:
//     1. apb_sys_driver  — drives system-side inputs (transfer, address, data)
//     2. apb_sequencer   — arbitrates transaction flow from sequences to driver
//     3. apb_sys_monitor — passively captures system requests for scoreboard
//
//   ACTIVE vs PASSIVE MODE:
//     - UVM_ACTIVE (default): All three components are instantiated. The agent
//       both drives stimulus AND monitors the interface.
//     - UVM_PASSIVE: Only the monitor is instantiated. The agent only observes
//       without driving — useful for protocol checking without stimulus generation.
//
//   CONNECTIONS:
//     In the connect_phase, the driver's seq_item_port is wired to the
//     sequencer's seq_item_export, creating the transaction delivery pipeline:
//       Sequence → Sequencer → Driver → DUT
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_sys_agent extends uvm_agent;

  `uvm_component_utils(apb_sys_agent)    // Register with UVM factory

  // Sub-components
  apb_sys_driver    drv;    // Active driver — drives system-side signals
  apb_sys_monitor   mon;    // Passive monitor — captures expected transactions
  apb_sequencer     sqr;    // Sequencer — feeds transactions from sequences to driver

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_sys_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE
  // The monitor is ALWAYS created (needed for scoreboard even in passive mode).
  // The driver and sequencer are only created if the agent is ACTIVE.
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always needed — it feeds the scoreboard's expected port
    mon = apb_sys_monitor::type_id::create("mon", this);

    // Driver and sequencer only exist in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_sys_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // CONNECT PHASE
  // Wire the driver's request port to the sequencer's export port.
  // This creates the TLM connection: Sequencer FIFO → Driver pull
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass
