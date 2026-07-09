`include "uvm_macros.svh"
import uvm_pkg::*;

class slave_monitor extends uvm_monitor;
  `uvm_component_utils(slave_monitor)

  virtual apb_if vif;

  // Sends one COMPLETION per finished transfer to the scoreboard
  uvm_analysis_port #(apb_seq_item) ap_out;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap_out = new("ap_out", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SLV_MON", "Virtual interface not set for slave_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item tr;

    forever begin
      @(vif.monitor_cb);

      // Completion = the exact cycle the transfer finishes
      // (PENABLE high AND PREADY high)
      if (vif.PRESETn === 1'b1 &&
          vif.monitor_cb.PENABLE === 1'b1 &&
          vif.monitor_cb.PREADY  === 1'b1) begin

        tr = apb_seq_item::type_id::create("comp");

        tr.paddr   = vif.monitor_cb.PADDR;
        tr.pwrite  = vif.monitor_cb.PWRITE;
        tr.pwdata  = vif.monitor_cb.PWDATA;
        tr.rdata   = vif.monitor_cb.PRDATA;
        tr.psel1   = vif.monitor_cb.PSEL1;
        tr.psel2   = vif.monitor_cb.PSEL2;
        tr.penable = vif.monitor_cb.PENABLE;

        `uvm_info("SLV_MON",
          $sformatf("COMPLETION: PADDR=0x%0h PWRITE=%0b PWDATA=0x%0h PRDATA=0x%0h PSEL=%0b%0b",
                    tr.paddr, tr.pwrite, tr.pwdata, tr.rdata, tr.psel1, tr.psel2),
          UVM_MEDIUM)

        ap_out.write(tr);
      end
    end
  endtask

endclass