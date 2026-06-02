// ============================================================================
// FILE: apb_driver.sv
// DESCRIPTION:
//   The Driver converts abstract transactions (apb_seq_item) into
//   pin-level signal wiggles on the APB interface.
//
//   APB PROTOCOL FLOW (what the driver implements):
//   -----------------------------------------------
//   Cycle 1 (SETUP phase):
//     - Assert PSEL = 1
//     - Drive PADDR, PWDATA, PWRITE
//     - Keep PENABLE = 0
//
//   Cycle 2 (ACCESS phase):
//     - Assert PENABLE = 1
//     - Wait for PREADY = 1 from the slave
//
//   Cycle 3 (done):
//     - Deassert PSEL, PENABLE
//     - If read: capture PRDATA1
// ============================================================================

class apb_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_driver)

  // Handle to the virtual interface (the "wire" connection to the DUT)
  virtual apb_if.driver vif;

  // ---- Constructor ----
  function new(string name = "apb_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase: Get the interface handle from config_db ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  // ---- Run Phase: The main loop that drives transactions forever ----
  task run_phase(uvm_phase phase);

    // Initialize all signals to idle state
    vif.driver_cb.PSEL    <= 0;
    vif.driver_cb.PENABLE <= 0;
    vif.driver_cb.PADDR   <= 0;
    vif.driver_cb.PWDATA  <= 0;
    vif.driver_cb.PWRITE  <= 0;

    forever begin
      apb_seq_item item;

      // Step 1: Get the next transaction from the sequencer
      seq_item_port.get_next_item(item);

      `uvm_info("DRV", $sformatf("Driving: %s", item.convert2string()), UVM_MEDIUM)

      // Step 2: SETUP phase
      @(vif.driver_cb);
      vif.driver_cb.PSEL    <= 1;
      vif.driver_cb.PENABLE <= 0;
      vif.driver_cb.PADDR   <= item.addr;
      vif.driver_cb.PWRITE  <= item.write;
      if (item.write)
        vif.driver_cb.PWDATA <= item.wdata;

      // Step 3: ACCESS phase (one clock later)
      @(vif.driver_cb);
      vif.driver_cb.PENABLE <= 1;

      // Step 4: Wait for PREADY from the slave
      // In this DUT, PREADY goes high combinationally with PENABLE,
      // so we sample it on the next clock edge.
      @(vif.driver_cb);
      while (!vif.driver_cb.PREADY) begin
        @(vif.driver_cb);
      end

      // Step 5: Capture read data if this was a read transaction
      if (!item.write) begin
        item.rdata = vif.driver_cb.PRDATA1;
      end

      // Step 6: Return to IDLE — deassert bus signals
      vif.driver_cb.PSEL    <= 0;
      vif.driver_cb.PENABLE <= 0;

      // Step 7: Tell the sequencer we're done with this item
      seq_item_port.item_done();
    end
  endtask

endclass
