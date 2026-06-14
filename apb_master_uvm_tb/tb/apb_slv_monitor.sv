// =============================================================================
// FILE: apb_slv_monitor.sv
// DESCRIPTION:
//   APB Slave/Bus Monitor — a PASSIVE monitor observing the APB bus signals
//   between the Master DUT and the Slave Driver.
//
//   This monitor captures COMPLETED APB transactions by detecting the handshake
//   completion condition: PENABLE=1 AND PREADY=1 AND (PSEL1=1 OR PSEL2=1).
//   When this condition is met, it means a valid transfer has completed on the bus.
//
//   The captured transactions are broadcast as "ACTUAL" items to the scoreboard,
//   which compares them against the "EXPECTED" items from the system monitor.
//
//   DATA FLOW:
//     APB bus signals → apb_slv_monitor → scoreboard.act_port (actual comparison)
//
//   SIGNALS SAMPLED (via monitor_cb clocking block):
//     - PSEL1, PSEL2  : Which slave was selected
//     - PENABLE        : ACCESS phase indicator
//     - PADDR          : Transaction target address
//     - PWRITE         : Transaction direction (1=write, 0=read)
//     - PWDATA         : Write data on the bus
//     - PRDATA         : Read data on the bus
//     - PREADY         : Handshake completion signal
//     - PSLVERR        : Error status flag
//
//   DELTA-CYCLE ORDERING:
//     A #0 (delta-cycle delay) is inserted before broadcasting the actual item.
//     This ensures the system monitor has already pushed its expected item to
//     the scoreboard queue before this monitor triggers the comparison.
//     Without this delay, the scoreboard might receive the actual item first
//     and find an empty expected queue, causing a false error.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_slv_monitor extends uvm_monitor;

  `uvm_component_utils(apb_slv_monitor)    // Register with UVM factory

  virtual apb_if vif;                      // Virtual interface handle

  // ---------------------------------------------------------------------------
  // ANALYSIS PORT
  // Broadcasts captured "actual" bus transactions to any connected subscriber.
  // In this testbench, it's connected to scoreboard.act_port.
  // ---------------------------------------------------------------------------
  uvm_analysis_port #(apb_seq_item) ap;

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_slv_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE
  // Create the analysis port and retrieve virtual interface from config_db.
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SLV_MON", "Could not get virtual interface 'vif' from config_db")
  endfunction

  // ---------------------------------------------------------------------------
  // RUN PHASE — passive bus observation loop
  //
  // Every clock cycle, the monitor samples the APB bus signals and checks for
  // a completed handshake. The APB protocol defines a transfer as complete when:
  //   PENABLE = 1 (ACCESS phase)
  //   PREADY  = 1 (Slave ready)
  //   PSELx   = 1 (A slave is selected)
  //
  // When all three conditions are met:
  //   1. Create a new apb_seq_item
  //   2. Capture ALL bus signals into the item's response fields
  //   3. Wait one delta cycle (#0) for sys_monitor ordering
  //   4. Broadcast the item to the scoreboard via analysis port
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    forever begin
      @(vif.monitor_cb);

      // Check for completed APB handshake: PENABLE=1, PREADY=1, and a slave is selected
      if (vif.monitor_cb.PENABLE === 1'b1 && vif.monitor_cb.PREADY === 1'b1 && (vif.monitor_cb.PSEL1 === 1'b1 || vif.monitor_cb.PSEL2 === 1'b1)) begin
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");

        // Capture the complete bus snapshot into the transaction item
        item.paddr   = vif.monitor_cb.PADDR;     // Transaction address
        item.pwdata  = vif.monitor_cb.PWDATA;     // Write data (valid for writes)
        item.pwrite  = vif.monitor_cb.PWRITE;     // Direction: 1=write, 0=read
        item.rdata   = vif.monitor_cb.PRDATA;     // Read data (valid for reads)
        item.psel1   = vif.monitor_cb.PSEL1;      // Slave 1 select status
        item.psel2   = vif.monitor_cb.PSEL2;      // Slave 2 select status
        item.penable = vif.monitor_cb.PENABLE;     // Should always be 1 here
        item.pslverr = vif.monitor_cb.PSLVERR;    // Error flag status

        `uvm_info("SLV_MON", $sformatf("Captured APB Bus Transaction: addr=0x%03h pwrite=%0b data=0x%02h", item.paddr, item.pwrite, item.pwrite ? item.pwdata : item.rdata), UVM_MEDIUM)

        // Delta-cycle delay: ensures sys_monitor's expected item reaches the
        // scoreboard queue BEFORE this actual item triggers the comparison.
        // Without this, we'd have a race condition between the two monitors.
        #0;
        ap.write(item);    // Broadcast to scoreboard's actual port
      end
    end
  endtask

endclass
