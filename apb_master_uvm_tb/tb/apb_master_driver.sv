// ============================================================================
// FILE: apb_master_driver.sv
// DESCRIPTION:
//   The Driver for the APB Master Bridge testbench.
//
//   KEY DIFFERENCE FROM SLAVE TB:
//   In the slave TB, the driver implemented the APB protocol directly.
//   Here, the driver only drives the SYSTEM SIDE of the master:
//     - transfer, READ_WRITE, apb_write_paddr, apb_read_paddr, apb_write_data
//   The MASTER DUT itself generates the APB protocol (PSEL, PENABLE, etc.)
//   A separate slave responder (in tb_top) provides PREADY and PRDATA.
//
//   DRIVER PROTOCOL:
//   ----------------
//   1. Assert transfer=1, drive address/data/read_write
//   2. Wait for the DUT to complete the APB handshake (PENABLE=1, PREADY=1)
//   3. Capture apb_read_data_out for reads
//   4. Deassert transfer for 1 idle cycle
// ============================================================================

class apb_master_driver extends uvm_driver #(apb_master_seq_item);

  `uvm_component_utils(apb_master_driver)

  // Handle to the virtual interface
  virtual apb_master_if vif;

  // ---- Constructor ----
  function new(string name = "apb_master_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase: Get interface handle ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_master_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  // ---- Run Phase: Main driving loop ----
  task run_phase(uvm_phase phase);

    // Initialize all system-side signals to idle
    vif.driver_cb.transfer        <= 0;
    vif.driver_cb.READ_WRITE      <= 0;
    vif.driver_cb.apb_write_paddr <= 0;
    vif.driver_cb.apb_read_paddr  <= 0;
    vif.driver_cb.apb_write_data  <= 0;

    forever begin
      apb_master_seq_item item;
      int timeout_cnt;

      // Step 1: Get next transaction from sequencer
      seq_item_port.get_next_item(item);

      `uvm_info("DRV", $sformatf("Driving: addr=0x%03h wdata=0x%02h read=%0b",
                                  item.addr, item.wdata, item.read), UVM_MEDIUM)

      // Step 2: Drive system-side inputs
      @(vif.driver_cb);
      vif.driver_cb.transfer   <= 1;
      vif.driver_cb.READ_WRITE <= item.read;
      if (item.read) begin
        // For reads: drive the read address
        vif.driver_cb.apb_read_paddr <= item.addr;
      end
      else begin
        // For writes: drive write address and data
        vif.driver_cb.apb_write_paddr <= item.addr;
        vif.driver_cb.apb_write_data  <= item.wdata;
      end

      // Step 3: Wait for the DUT's APB transfer to complete
      // The DUT goes IDLE → SETUP → ENABLE.
      // The slave responder drives PREADY=1 when PENABLE=1.
      // We wait until we see PREADY=1 (transfer done).
      timeout_cnt = 0;
      do begin
        @(vif.driver_cb);
        timeout_cnt++;
        if (timeout_cnt > 20) begin
          `uvm_error("DRV", "Timeout waiting for PREADY!")
          break;
        end
      end while (!vif.driver_cb.PREADY);

      // Step 4: Capture outputs
      if (item.read)
        item.rdata = vif.driver_cb.apb_read_data_out;
      item.pslverr = vif.driver_cb.PSLVERR;

      // Step 5: Idle gap — deassert transfer for 1 cycle
      // This gives the FSM time to return to IDLE between transactions.
      @(vif.driver_cb);
      vif.driver_cb.transfer <= 0;
      @(vif.driver_cb);    // Wait one more cycle in IDLE

      // Step 6: Done with this item
      seq_item_port.item_done();
    end
  endtask

endclass
