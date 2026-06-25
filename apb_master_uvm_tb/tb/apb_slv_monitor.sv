`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_slv_monitor extends uvm_monitor;
  `uvm_component_utils(apb_slv_monitor)
  virtual apb_if vif;
  uvm_analysis_port #(apb_seq_item) ap;

  function new(string name = "apb_slv_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SLV_MON", "Could not get virtual interface 'vif' from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(vif.monitor_cb);

      // Emit at completed APB handshake
      if (vif.monitor_cb.PENABLE && vif.monitor_cb.PREADY &&
          (vif.monitor_cb.PSEL1 || vif.monitor_cb.PSEL2)) begin

        apb_seq_item item = apb_seq_item::type_id::create("item");
        item.paddr   = vif.monitor_cb.PADDR;
        item.pwrite  = vif.monitor_cb.PWRITE;
        item.pwdata  = vif.monitor_cb.PWDATA;
        item.rdata   = vif.monitor_cb.PRDATA;
        item.psel1   = vif.monitor_cb.PSEL1;
        item.psel2   = vif.monitor_cb.PSEL2;
        item.penable = vif.monitor_cb.PENABLE;

        `uvm_info("SLV_MON", $sformatf("ACTUAL %s: paddr=0x%03h data=0x%02h psel1=%0b psel2=%0b",
                  item.pwrite ? "WRITE" : "READ", item.paddr,
                  item.pwrite ? item.pwdata : item.rdata,
                  item.psel1, item.psel2), UVM_LOW)
        ap.write(item);
      end
    end
  endtask
endclass
