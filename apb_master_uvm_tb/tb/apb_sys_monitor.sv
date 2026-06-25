`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_sys_monitor extends uvm_monitor;
  `uvm_component_utils(apb_sys_monitor)
  virtual apb_if vif;
  uvm_analysis_port #(apb_seq_item) ap;

  function new(string name = "apb_sys_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SYS_MON", "Could not get virtual interface 'vif' from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(vif.sys_monitor_cb);

      // Emit at handshake completion — system inputs are still valid (driver holds transfer)
      if (vif.sys_monitor_cb.PENABLE && vif.sys_monitor_cb.PREADY &&
          (vif.sys_monitor_cb.PSEL1 || vif.sys_monitor_cb.PSEL2)) begin

        apb_seq_item item = apb_seq_item::type_id::create("item");
        item.read = vif.sys_monitor_cb.READ_WRITE;

        if (item.read) begin
          item.addr  = vif.sys_monitor_cb.apb_read_paddr;
          item.rdata = vif.sys_monitor_cb.apb_read_data_out;
        end else begin
          item.addr  = vif.sys_monitor_cb.apb_write_paddr;
          item.wdata = vif.sys_monitor_cb.apb_write_data;
        end

        `uvm_info("SYS_MON", $sformatf("EXPECTED %s: addr=0x%03h data=0x%02h",
                  item.read ? "READ" : "WRITE", item.addr,
                  item.read ? item.rdata : item.wdata), UVM_LOW)
        ap.write(item);
      end
    end
  endtask
endclass
