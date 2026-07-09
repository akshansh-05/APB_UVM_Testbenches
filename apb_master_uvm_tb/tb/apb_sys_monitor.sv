`include "uvm_macros.svh"
import uvm_pkg::*;

class sys_monitor extends uvm_monitor;
  `uvm_component_utils(sys_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_seq_item) ap_in;

  // Edge-detection: remember if we were in SETUP last cycle
  bit in_setup_prev;

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
    bit in_setup_now;

    in_setup_prev = 1'b0;

    forever begin
      @(vif.sys_monitor_cb);

      if (vif.PRESETn !== 1'b1) begin
        in_setup_prev = 1'b0;   // reset edge tracking
        continue;
      end

      // SETUP phase this cycle?
      in_setup_now = (vif.sys_monitor_cb.PSEL1 === 1'b1 ||
                      vif.sys_monitor_cb.PSEL2 === 1'b1) &&
                      vif.sys_monitor_cb.PENABLE === 1'b0;

      // Log a request only on the RISING edge of SETUP (new SETUP entry)
      if (in_setup_now && !in_setup_prev) begin
        tr = apb_seq_item::type_id::create("req");
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

      in_setup_prev = in_setup_now;
    end
  endtask

endclass