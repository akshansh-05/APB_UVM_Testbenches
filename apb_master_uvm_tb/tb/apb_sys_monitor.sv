`include "uvm_macros.svh"
import uvm_pkg::*;

class sys_monitor extends uvm_monitor;
  `uvm_component_utils(sys_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_seq_item) ap_in;

  bit transfer_prev;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap_in = new("ap_in", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SYS_MON", "Virtual interface not set for sys_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item tr;

    transfer_prev = 1'b0;

    forever begin
      @(vif.sys_monitor_cb);

      if (vif.PRESETn !== 1'b1) begin
        transfer_prev = 1'b0;
        continue;
      end

      // Rising edge of transfer = one new system request.
      // Samples the SYSTEM-SIDE request (ground truth), independent of
      // what the bridge produces on the APB bus.
      if (vif.sys_monitor_cb.transfer === 1'b1 && transfer_prev === 1'b0) begin
        tr = apb_seq_item::type_id::create("exp");
        tr.read  = vif.sys_monitor_cb.READ_WRITE;
        tr.addr  = vif.sys_monitor_cb.READ_WRITE ?
                   vif.sys_monitor_cb.apb_read_paddr :
                   vif.sys_monitor_cb.apb_write_paddr;
        tr.wdata = vif.sys_monitor_cb.apb_write_data;

        `uvm_info("SYS_MON",
          $sformatf("REQUEST: %s addr=0x%0h wdata=0x%0h",
                    tr.read ? "READ" : "WRITE", tr.addr, tr.wdata),
          UVM_MEDIUM)

        ap_in.write(tr);
      end

      transfer_prev = vif.sys_monitor_cb.transfer;
    end
  endtask

endclass