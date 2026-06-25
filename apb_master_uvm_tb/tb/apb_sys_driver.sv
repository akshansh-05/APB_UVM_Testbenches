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

    // Init all system-side signals to idle
    vif.master_cb.transfer        <= 0;
    vif.master_cb.READ_WRITE      <= 0;
    vif.master_cb.apb_write_paddr <= 0;
    vif.master_cb.apb_read_paddr  <= 0;
    vif.master_cb.apb_write_data  <= 0;

    forever begin
      apb_seq_item item;
      seq_item_port.get_next_item(item);

      // Drive transfer=1 and HOLD it through SETUP and ENABLE
      vif.master_cb.transfer   <= 1;
      vif.master_cb.READ_WRITE <= item.read;

      if (item.read) begin
        vif.master_cb.apb_read_paddr  <= item.addr;
        vif.master_cb.apb_write_paddr <= '0;
        vif.master_cb.apb_write_data  <= '0;
      end else begin
        vif.master_cb.apb_write_paddr <= item.addr;
        vif.master_cb.apb_write_data  <= item.wdata;
        vif.master_cb.apb_read_paddr  <= '0;
      end

      // Wait for completion: PENABLE && PREADY means ACCESS handshake done
      // Cannot gate on PREADY alone — slave asserts PREADY during SETUP
      do @(vif.master_cb);
      while (!(vif.master_cb.PENABLE && vif.master_cb.PREADY));

      // For reads, capture the data DUT returned to system side
      if (item.read)
        item.rdata = vif.master_cb.apb_read_data_out;

      // Now deassert transfer — FSM will see transfer=0 next cycle
      vif.master_cb.transfer <= 0;
      @(vif.master_cb); // let the deassert propagate

      seq_item_port.item_done();
    end
  endtask
endclass
