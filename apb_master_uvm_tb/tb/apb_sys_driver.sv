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
    apb_seq_item tr;

    reset_signals();

wait(vif.PRESETn == 1'b1);
    @(vif.master_cb);
    forever begin
      // Peek without blocking so transfer can stay HIGH across a burst
      seq_item_port.try_next_item(tr);

      if (tr == null) begin
        // Sequencer empty -> master no longer requesting: drop transfer
        vif.master_cb.transfer <= 1'b0;
        @(vif.master_cb);
      end
      else begin
        drive_transfer(tr);
        seq_item_port.item_done();
      end
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

    // transfer stays HIGH through the burst; it is dropped only in run_phase
    // when try_next_item finds the sequencer empty.
    vif.master_cb.transfer        <= 1'b1;
    vif.master_cb.READ_WRITE      <= tr.read;
    vif.master_cb.apb_read_paddr  <= tr.addr;
    vif.master_cb.apb_write_paddr <= tr.addr;
    vif.master_cb.apb_write_data  <= tr.wdata;

    `uvm_info("SYS_DRV",
      $sformatf("Driving %s | addr=0x%0h wdata=0x%0h",
                tr.read ? "READ" : "WRITE", tr.addr, tr.wdata),
      UVM_MEDIUM)

    // Hold stimulus stable until APB completion. transfer NOT dropped here.
    do @(vif.master_cb);
    while (!(vif.master_cb.PENABLE === 1'b1 && vif.master_cb.PREADY === 1'b1));

    `uvm_info("SYS_DRV", "Transfer accepted (PENABLE & PREADY)", UVM_HIGH)
  endtask

endclass