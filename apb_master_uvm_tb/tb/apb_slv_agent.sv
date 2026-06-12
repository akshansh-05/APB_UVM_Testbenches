// =============================================================================
// FILE: apb_slv_agent.sv
// DESCRIPTION:
//   APB Slave Agent — the ACTIVE agent on the slave side of the APB bus.
//
//   This agent groups three sub-components that together handle the slave-side
//   interaction with the APB Master Bridge DUT:
//     1. apb_slv_driver — reactive driver that responds to bus handshakes
//     2. apb_sequencer  — arbitrates transaction flow from sequences to driver
//     3. apb_monitor    — passively captures completed APB bus transactions
//
//   ACTIVE vs PASSIVE MODE:
//     - UVM_ACTIVE (default): All three components are instantiated. The agent
//       both drives slave responses AND monitors the bus interface.
//     - UVM_PASSIVE: Only the monitor is instantiated. The agent only observes
//       without driving — useful for protocol checking without slave responses.
//
//   CONNECTIONS:
//     In the connect_phase, the driver's seq_item_port is wired to the
//     sequencer's seq_item_export, creating the transaction delivery pipeline:
//       Sequence → Sequencer → Driver → DUT
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_slv_agent extends uvm_agent;

  `uvm_component_utils(apb_slv_agent)    // Register with UVM factory

  // Sub-components
  apb_slv_driver    drv;    // Active driver — responds to bus handshakes
  apb_monitor       mon;    // Passive monitor — captures actual bus transactions
  apb_sequencer     sqr;    // Sequencer — feeds transactions from sequences to driver

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_slv_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE
  // The monitor is ALWAYS created (needed for scoreboard even in passive mode).
  // The driver and sequencer are only created if the agent is ACTIVE.
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always needed — it feeds the scoreboard's actual port
    mon = apb_monitor::type_id::create("mon", this);

    // Driver and sequencer only exist in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_slv_driver::type_id::create("drv", this);
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
