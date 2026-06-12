`include "uvm_macros.svh"
import uvm_pkg::*;

// The standalone APB bus monitor passively samples transaction pins on the bus,
// checks protocol compliance, and broadcasts completed transactions to the scoreboard.
class apb_monitor extends uvm_monitor;

  `uvm_component_utils(apb_monitor)

  virtual apb_if.monitor vif;

  uvm_analysis_port #(apb_seq_item) ap;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "Could not get virtual interface 'vif' from config_db")
  endfunction

    // Run Phase: main simulation execution loop handling active driving or passive monitoring
  task run_phase(uvm_phase phase);
    forever begin
      // Sample the bus on each clock. A valid transaction is completed only when PSEL, PENABLE, and PREADY are all asserted.
      @(vif.monitor_cb);
      if (vif.monitor_cb.PSEL && vif.monitor_cb.PENABLE) begin

        if (vif.monitor_cb.PREADY) begin
          apb_seq_item item = apb_seq_item::type_id::create("item");

          item.addr  = vif.monitor_cb.PADDR;
          item.write = vif.monitor_cb.PWRITE;
          item.wdata = vif.monitor_cb.PWDATA;
          item.rdata = vif.monitor_cb.PRDATA1;

          `uvm_info("MON", $sformatf("Observed: %s", item.convert2string()), UVM_MEDIUM)

          ap.write(item);
        end
      end
    end
  endtask

endclass
