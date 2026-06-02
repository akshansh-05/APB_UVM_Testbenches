// ============================================================================
// FILE: apb_monitor.sv
// DESCRIPTION:
//   The Monitor passively OBSERVES the APB bus (it never drives signals).
//   It watches for completed transactions and broadcasts them to the
//   Scoreboard via an analysis port.
//
//   KEY RULE: A monitor must NEVER drive any DUT signals.
//   It only watches and reports.
//
//   HOW IT WORKS:
//   1. Wait for PSEL=1 and PENABLE=1 (the ACCESS phase).
//   2. Sample all bus signals (addr, data, write/read, ready).
//   3. Package them into an apb_seq_item.
//   4. Send the item out through the analysis port.
// ============================================================================

class apb_monitor extends uvm_monitor;

  `uvm_component_utils(apb_monitor)

  // Handle to the virtual interface
  virtual apb_if.monitor vif;

  // Analysis port: broadcasts observed transactions to subscribers
  // (like the Scoreboard). Think of it as a "radio station" that
  // the Scoreboard tunes into.
  uvm_analysis_port #(apb_seq_item) ap;

  // ---- Constructor ----
  function new(string name = "apb_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "Could not get virtual interface 'vif' from config_db")
  endfunction

  // ---- Run Phase: Watch the bus forever ----
  task run_phase(uvm_phase phase);
    forever begin

      // Wait for the ACCESS phase: PSEL=1 AND PENABLE=1
      @(vif.monitor_cb);
      if (vif.monitor_cb.PSEL && vif.monitor_cb.PENABLE) begin

        // Only capture when PREADY is also high (transfer complete)
        if (vif.monitor_cb.PREADY) begin
          apb_seq_item item = apb_seq_item::type_id::create("item");

          // Sample all observed signals
          item.addr  = vif.monitor_cb.PADDR;
          item.write = vif.monitor_cb.PWRITE;
          item.wdata = vif.monitor_cb.PWDATA;
          item.rdata = vif.monitor_cb.PRDATA1;

          `uvm_info("MON", $sformatf("Observed: %s", item.convert2string()), UVM_MEDIUM)

          // Broadcast to all listeners (Scoreboard, coverage, etc.)
          ap.write(item);
        end
      end
    end
  endtask

endclass
