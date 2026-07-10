`include "uvm_macros.svh"
import uvm_pkg::*;

class sys_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(sys_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SYS_DRV", "Virtual interface not set for sys_driver")
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();

    forever begin
      seq_item_port.get_next_item(req);
      drive_transfer(req);
      seq_item_port.item_done();
    end
  endtask

  task reset_signals();
    vif.master_cb.transfer         <= 1'b0;
    vif.master_cb.READ_WRITE       <= 1'b0;
    vif.master_cb.apb_write_paddr  <= '0;
    vif.master_cb.apb_read_paddr   <= '0;
    vif.master_cb.apb_write_data   <= '0;
  endtask

  task drive_transfer(apb_seq_item tr);
    @(vif.master_cb);

    vif.master_cb.transfer        <= 1'b1;
    vif.master_cb.READ_WRITE      <= tr.read;
    vif.master_cb.apb_read_paddr  <= tr.addr;
    vif.master_cb.apb_write_paddr <= tr.addr;
    vif.master_cb.apb_write_data  <= tr.wdata;

    `uvm_info("SYS_DRV",
      $sformatf("Driving %s | addr=0x%0h wdata=0x%0h",
                tr.read ? "READ" : "WRITE", tr.addr, tr.wdata),
      UVM_MEDIUM)

    do @(vif.master_cb);
    while (!(vif.master_cb.PENABLE === 1'b1 && vif.master_cb.PREADY === 1'b1));

    // Per-item pulse: drop transfer after completion; next item re-raises it.
    vif.master_cb.transfer <= 1'b0;

    `uvm_info("SYS_DRV", "Transfer accepted (PENABLE & PREADY)", UVM_HIGH)
  endtask

endclass