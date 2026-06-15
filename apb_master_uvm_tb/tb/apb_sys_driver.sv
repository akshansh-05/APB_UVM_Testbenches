`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_sys_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_sys_driver)

  virtual apb_if vif;

  function new(string name = "apb_sys_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    wait(vif.PRESETn === 1'b1);
    @(vif.master_cb);

    // Initialize system-side signals to idle
    vif.master_cb.transfer        <= 0;
    vif.master_cb.READ_WRITE      <= 0;
    vif.master_cb.apb_write_paddr <= 0;
    // vif.master_cb.apb_read_paddr  <= 0;  // TODO: uncomment when adding read support
    vif.master_cb.apb_write_data  <= 0;

    forever begin
      apb_seq_item item;
      int timeout_cnt;

      seq_item_port.get_next_item(item);

      // Drive WRITE transaction signals onto the DUT's system-side inputs
      vif.master_cb.transfer        <= 1;
      vif.master_cb.READ_WRITE      <= item.read;       // 0=Write
      vif.master_cb.apb_write_paddr <= item.addr;
      vif.master_cb.apb_write_data  <= item.wdata;

      `uvm_info("SYS_DRV", "======== Signals Driven to DUT (WRITE) =============", UVM_LOW)
      `uvm_info("SYS_DRV", $sformatf("  transfer        = 1"),                     UVM_LOW)
      `uvm_info("SYS_DRV", $sformatf("  READ_WRITE      = %0b (0=Write)", item.read), UVM_LOW)
      `uvm_info("SYS_DRV", $sformatf("  apb_write_paddr = 0x%03h", item.addr),     UVM_LOW)
      `uvm_info("SYS_DRV", $sformatf("  apb_write_data  = 0x%02h", item.wdata),    UVM_LOW)
      `uvm_info("SYS_DRV", "====================================================", UVM_LOW)

      // TODO: uncomment when adding read support
      // if (item.read) begin
      //   vif.master_cb.apb_read_paddr <= item.addr;
      // end
      // else begin
      //   vif.master_cb.apb_write_paddr <= item.addr;
      //   vif.master_cb.apb_write_data  <= item.wdata;
      // end

      // Wait for PREADY handshake from slave
      timeout_cnt = 0;
      do begin
        @(vif.master_cb);
        timeout_cnt++;
        if (timeout_cnt > 20) begin
          `uvm_error("SYS_DRV", "Timeout waiting for PREADY!")
          break;
        end
      end while (!vif.master_cb.PREADY);

      if (item.read)
        item.rdata = vif.master_cb.apb_read_data_out;
      item.pslverr = vif.master_cb.PSLVERR;

      vif.master_cb.transfer <= 0;
      @(vif.master_cb);

      seq_item_port.item_done();
    end
  endtask

endclass
