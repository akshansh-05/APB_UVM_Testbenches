// =============================================================================
// FILE: apb_slv_agent.sv
// DESCRIPTION:
//   APB Slave Agent — the REACTIVE agent emulating a slave device on the APB bus.
//
//   This agent contains only a single sub-component:
//     - apb_slv_driver: Reactive driver that responds to bus handshakes
//
//   WHY NO SEQUENCER?
//     Unlike the system agent, the slave agent is purely REACTIVE — it does not
//     initiate transactions. It only RESPONDS to what the master DUT puts on
//     the bus (PSEL, PENABLE, PADDR, PWRITE, PWDATA). Therefore, it does not
//     need a sequencer to feed it transactions.
//
//   WHY NO MONITOR?
//     The bus-side monitoring is handled by the standalone apb_monitor component
//     in the environment, which observes the bus signals between master and slave.
//     Having a separate monitor inside the slave agent would be redundant.
//
//   The slave agent is always active (it must always respond to the master),
//   so there is no active/passive mode distinction.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_slv_agent extends uvm_agent;

  `uvm_component_utils(apb_slv_agent)    // Register with UVM factory

  apb_slv_driver    drv;    // Reactive slave driver — responds to bus handshakes

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_slv_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE
  // Create the reactive slave driver. No sequencer or monitor needed.
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = apb_slv_driver::type_id::create("drv", this);
  endfunction

endclass
