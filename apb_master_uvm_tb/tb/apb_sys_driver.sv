// ============================================================================
// FILE: apb_sys_driver.sv
// DESCRIPTION: Active system-side driver for the APB Master TB
// ============================================================================

class apb_sys_driver extends uvm_driver #(apb_seq_item); // Extends uvm_driver parameterized with apb_seq_item

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(apb_sys_driver)                   // Factory registration macro for UVM components

  // ---- VIRTUAL INTERFACE HANDLE ----
  virtual apb_if vif;                                    // Handle to virtual interface apb_if

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_sys_driver", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls the base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM BUILD PHASE ----
  function void build_phase(uvm_phase phase);            // Build phase callback
    super.build_phase(phase);                            // Calls parent build phase
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif)) // Retrieves virtual interface handle from config db
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db") // Stops simulation with fatal error if retrieval fails
  endfunction                                            // End of build phase declaration

  // ---- UVM RUN PHASE ----
  task run_phase(uvm_phase phase);                       // Run phase time-consuming task
    @(vif.master_cb);                                    // Syncs to the first active rising clock edge

    vif.master_cb.transfer        <= 0;                  // Clears transfer request signal
    vif.master_cb.READ_WRITE      <= 0;                  // Resets read/write flag to default
    vif.master_cb.apb_write_paddr <= 0;                  // Resets system write address bus
    vif.master_cb.apb_read_paddr  <= 0;                  // Resets system read address bus
    vif.master_cb.apb_write_data  <= 0;                  // Resets system write data bus

    forever begin                                        // Infinite loop representing driver runtime
      apb_seq_item item;                                 // Temporary transaction container
      int timeout_cnt;                                   // Timeout counter to detect hung simulation

      seq_item_port.get_next_item(item);                 // Fetches next transaction from sequencer (blocking)

      `uvm_info("DRV", $sformatf("Driving: addr=0x%03h wdata=0x%02h read=%0b", item.addr, item.wdata, item.read), UVM_MEDIUM) // Prints debug info for transaction

      vif.master_cb.transfer   <= 1;                     // Asserts system transfer request to DUT
      vif.master_cb.READ_WRITE <= item.read;             // Passes the read/write flag from item to system bus
      if (item.read) begin                               // Checks if transaction is a read
        vif.master_cb.apb_read_paddr <= item.addr;       // Drives read address onto system read address lines
      end                                                // End read path conditional branch
      else begin                                         // Handles write path
        vif.master_cb.apb_write_paddr <= item.addr;      // Drives write address onto system write address lines
        vif.master_cb.apb_write_data  <= item.wdata;     // Drives write data onto system write data lines
      end                                                // End write path conditional branch

      timeout_cnt = 0;                                   // Resets timeout safety counter
      do begin                                           // Wait loop for completion handshake
        @(vif.master_cb);                                // Syncs to next rising clock cycle
        timeout_cnt++;                                   // Increments safety timeout value
        if (timeout_cnt > 20) begin                      // Safety limit of 20 clock cycles exceeded
          `uvm_error("DRV", "Timeout waiting for PREADY!") // Reports handshake error to console
          break;                                         // Forces break from wait loop to avoid hang
        end                                              // End timeout threshold check
      end while (!vif.master_cb.PREADY);                 // Loop finishes when PREADY goes high (handshake complete)

      if (item.read)                                     // Checks if the completed transfer was a read
        item.rdata = vif.master_cb.apb_read_data_out;    // Captures read data output from system-side bus
      item.pslverr = vif.master_cb.PSLVERR;              // Captures observed bus error response state

      vif.master_cb.transfer <= 0;                       // Deasserts system transfer request to stop back-to-back cycles
      @(vif.master_cb);                                  // Syncs clock cycle to let DUT clean up state

      seq_item_port.item_done();                         // Signals sequencer that item processing is fully completed
    end                                                  // End of forever loop block
  endtask                                                // End of run phase task declaration

endclass // End of apb_sys_driver class declaration
