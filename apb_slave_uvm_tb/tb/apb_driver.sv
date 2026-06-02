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

class apb_driver extends uvm_driver #(apb_seq_item); // Declare the driver class extending parameterized uvm_driver

  `uvm_component_utils(apb_driver) // Register with the UVM factory for dynamic allocation/overrides

  // Handle to the virtual interface (the "wire" connection to the DUT)
  virtual apb_if.driver vif; // Points to the driver clocking block modport in the interface

  // ---- Constructor ----
  // Standard UVM component constructor
  function new(string name = "apb_driver", uvm_component parent);
    super.new(name, parent); // Pass arguments to parent constructor (uvm_driver)
  endfunction // End of constructor

  // ---- Build Phase: Get the interface handle from config_db ----
  // Retrieves virtual interface handle from the global config database
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); // Always call super.build_phase to initialize parent class parts
    // Look up the virtual interface 'vif' inside config_db
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif)) // Check if lookup succeeds
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db") // Throw fatal error if missing
  endfunction // End of build phase

  // ---- Run Phase: The main loop that drives transactions forever ----
  // Executes during simulation. Runs a continuous loop fetching and driving transactions.
  task run_phase(uvm_phase phase);

    // Initialize all signals to idle state before starting the loop
    vif.driver_cb.PSEL    <= 0; // Select signal is set to inactive (low)
    vif.driver_cb.PENABLE <= 0; // Enable signal is set to inactive (low)
    vif.driver_cb.PADDR   <= 0; // Address bus is cleared to 0
    vif.driver_cb.PWDATA  <= 0; // Write data bus is cleared to 0
    vif.driver_cb.PWRITE  <= 0; // Read/Write control signal is set to read (low)

    forever begin // Infinite loop to fetch items as long as sequences are running
      apb_seq_item item; // Handle for storing the current transaction

      // Step 1: Get the next transaction from the sequencer
      seq_item_port.get_next_item(item); // Blocks until a sequence item is available from the sequencer

      `uvm_info("DRV", $sformatf("Driving: %s", item.convert2string()), UVM_MEDIUM) // Log the transaction

      // Step 2: SETUP phase
      @(vif.driver_cb); // Synchronize with the next active clock edge
      vif.driver_cb.PSEL    <= 1; // Assert PSEL (select this slave)
      vif.driver_cb.PENABLE <= 0; // Keep PENABLE low during setup phase (required by APB)
      vif.driver_cb.PADDR   <= item.addr; // Drive target address to PADDR
      vif.driver_cb.PWRITE  <= item.write; // Drive write/read mode control
      if (item.write) // If this is a write transaction
        vif.driver_cb.PWDATA <= item.wdata; // Drive data to be written onto PWDATA bus

      // Step 3: ACCESS phase (one clock later)
      @(vif.driver_cb); // Advance one clock cycle to enter access phase
      vif.driver_cb.PENABLE <= 1; // Assert PENABLE high to signal second cycle of transfer

      // Step 4: Wait for PREADY from the slave
      // In this DUT, PREADY goes high combinationally with PENABLE,
      // so we sample it on the next clock edge.
      @(vif.driver_cb); // Wait for the clock edge where we sample PREADY
      while (!vif.driver_cb.PREADY) begin // Loop if slave holds PREADY low (wait states)
        @(vif.driver_cb); // Wait for another clock cycle
      end // Exit loop once PREADY is sampled high (1)

      // Step 5: Capture read data if this was a read transaction
      if (!item.write) begin // Check if the current transaction is a Read operation
        item.rdata = vif.driver_cb.PRDATA1; // Capture read data returned by the slave
      end // End of read capture

      // Step 6: Return to IDLE — deassert bus signals
      vif.driver_cb.PSEL    <= 0; // Deassert select line
      vif.driver_cb.PENABLE <= 0; // Deassert enable line

      // Step 7: Tell the sequencer we're done with this item
      seq_item_port.item_done(); // Release the sequence item and unblock the sequence
    end // End of forever loop
  endtask // End of run_phase

endclass
