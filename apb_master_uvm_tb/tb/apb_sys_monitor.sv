// =============================================================================
// FILE: apb_sys_monitor.sv
// DESCRIPTION:
//   APB System Monitor — a PASSIVE monitor inside the system-side agent.
//
//   This monitor observes the system-side signals (the host/processor interface)
//   going INTO the DUT to capture what was REQUESTED. These captured transactions
//   become the "EXPECTED" reference for the scoreboard.
//
//   DATA FLOW:
//     System inputs → apb_sys_monitor → scoreboard.exp_port (expected queue)
//
//   The scoreboard later compares these expected transactions against the
//   "actual" transactions captured by the bus monitor (apb_monitor).
//
//   SIGNALS SAMPLED (via sys_monitor_cb clocking block):
//     - transfer         : Detects when a new transfer request is active
//     - READ_WRITE       : Captures direction (0=Write, 1=Read)
//     - apb_write_paddr  : Captures write address
//     - apb_read_paddr   : Captures read address
//     - apb_write_data   : Captures write data
//     - PREADY           : Waits for handshake completion
//     - apb_read_data_out: Captures read data returned to system (for reads)
//
//   IMPORTANT TIMING:
//     This monitor must push its expected item to the scoreboard BEFORE the
//     bus monitor pushes the actual item. This ordering is guaranteed by the
//     delta-cycle delay (#0) in apb_monitor.sv.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_sys_monitor extends uvm_monitor;

  `uvm_component_utils(apb_sys_monitor)    // Register with UVM factory

  virtual apb_if vif;                      // Virtual interface handle

  // ---------------------------------------------------------------------------
  // ANALYSIS PORT
  // Broadcasts captured "expected" transactions to any connected subscriber.
  // In this testbench, it's connected to scoreboard.exp_port.
  // ---------------------------------------------------------------------------
  uvm_analysis_port #(apb_seq_item) ap;

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_sys_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE
  // Create the analysis port and retrieve virtual interface from config_db.
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);    // Instantiate the TLM analysis port
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SYS_MON", "Could not get virtual interface 'vif' from config_db")
  endfunction

  // ---------------------------------------------------------------------------
  // RUN PHASE — passive observation loop
  //
  // Every clock cycle, the monitor checks if 'transfer' is asserted (and reset
  // is not active). When it detects an active transfer:
  //   1. Creates a new apb_seq_item
  //   2. Records the direction and address/data from system-side signals
  //   3. Waits until PREADY goes high (handshake complete)
  //   4. For reads: captures the read data returned by the DUT
  //   5. Broadcasts the item via analysis port to the scoreboard
  //
  // This item represents what the SYSTEM REQUESTED — the scoreboard will
  // compare it against what ACTUALLY HAPPENED on the APB bus.
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    forever begin
      @(vif.sys_monitor_cb);

      // Detect an active transfer request (transfer=1, reset not active)
      if (vif.sys_monitor_cb.transfer === 1'b1 && vif.PRESETn === 1'b1) begin
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");

        // Capture the transfer direction
        item.read = vif.sys_monitor_cb.READ_WRITE;   // 0=Write, 1=Read

        // Capture address and data based on direction
        if (item.read) begin
          item.addr = vif.sys_monitor_cb.apb_read_paddr;    // Read address
        end
        else begin
          item.addr  = vif.sys_monitor_cb.apb_write_paddr;  // Write address
          item.wdata = vif.sys_monitor_cb.apb_write_data;    // Write data
        end

        // Wait for the handshake to complete (PREADY goes high)
        // This ensures we capture the full transaction including response
        while (!vif.sys_monitor_cb.PREADY) begin
          @(vif.sys_monitor_cb);
        end

        // For reads: capture the data that the DUT returned to the system
        if (item.read)
          item.rdata = vif.sys_monitor_cb.apb_read_data_out;

        `uvm_info("SYS_MON", $sformatf("Captured System Expected Request: addr=0x%03h read=%0b data=0x%02h", item.addr, item.read, item.read ? item.rdata : item.wdata), UVM_MEDIUM)

        // Broadcast to scoreboard's expected port
        ap.write(item);
      end
    end
  endtask

endclass
