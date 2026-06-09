// ============================================================================
// FILE: apb_slv_driver.sv
// DESCRIPTION: Reactive slave-side driver with local memory for the APB Master TB
// ============================================================================

class apb_slv_driver extends uvm_driver #(apb_seq_item); // Extends standard uvm_driver parameterized with apb_seq_item

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(apb_slv_driver)                   // Registers driver with UVM factory

  // ---- VIRTUAL INTERFACE HANDLE ----
  virtual apb_if vif;                                    // Handle to virtual interface apb_if

  // ---- LOCAL MEMORY STORAGE ----
  protected bit [7:0] slave_mem [bit [8:0]];             // Local associative array acting as reactive slave RAM

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_slv_driver", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls parent base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM BUILD PHASE ----
  function void build_phase(uvm_phase phase);            // Build phase callback
    super.build_phase(phase);                            // Calls parent build phase
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif)) // Retrieves virtual interface handle from database
      `uvm_fatal("SLV_DRV", "Could not get virtual interface 'vif' from config_db") // Stops simulation with fatal error if retrieval fails
  endfunction                                            // End of build phase declaration

  // ---- UVM RUN PHASE ----
  task run_phase(uvm_phase phase);                       // Run phase time-consuming task
    wait(vif.PRESETn === 1'b1);                          // Blocks execution until reset is deasserted

    @(vif.slave_cb);                                     // Syncs to the first active rising clock edge
    vif.slave_cb.PREADY <= 1'b0;                         // Resets PREADY handshake line to default state (not ready)
    vif.slave_cb.PRDATA <= 8'h00;                        // Resets read data bus to default zero state

    forever begin                                        // Infinite reactive responder loop
      @(vif.slave_cb);                                   // Syncs to next rising clock cycle (inputs sampled here)

      if (vif.slave_cb.PSEL1 || vif.slave_cb.PSEL2) begin // Checks if the DUT selected either APB Slave 1 or Slave 2
        if (!vif.slave_cb.PENABLE) begin                 // Checks for the APB SETUP phase (PENABLE is low)
          vif.slave_cb.PREADY <= 1'b1;                   // Asserts PREADY high for next cycle (emulates zero wait-state response)
          if (!vif.slave_cb.PWRITE) begin                // Checks if current APB bus command is a read request
            if (slave_mem.exists(vif.slave_cb.PADDR)) begin // Checks if read address has data in local RAM
              vif.slave_cb.PRDATA <= slave_mem[vif.slave_cb.PADDR]; // Drives the previously written data onto PRDATA bus
              `uvm_info("SLV_DRV", $sformatf("Local RAM Read Hit: Addr=0x%03h, Data=0x%02h", vif.slave_cb.PADDR, slave_mem[vif.slave_cb.PADDR]), UVM_HIGH) // Prints hit details to console
            end                                          // End read hit block
            else begin                                   // Handles read miss scenario
              bit [7:0] fallback_data = vif.slave_cb.PADDR[7:0] ^ 8'hA5; // Computes predictable fallback pattern from address
              vif.slave_cb.PRDATA <= fallback_data;       // Drives fallback pattern onto PRDATA bus
              `uvm_info("SLV_DRV", $sformatf("Local RAM Read Miss: Addr=0x%03h, Fallback Data=0x%02h", vif.slave_cb.PADDR, fallback_data), UVM_HIGH) // Prints miss details to console
            end                                          // End read miss block
          end                                            // End read direction handling block
        end                                              // End SETUP phase handling block
        else if (vif.slave_cb.PENABLE && vif.slave_cb.PREADY) begin // Checks for the APB ACCESS phase completion (both high)
          if (vif.slave_cb.PWRITE) begin                 // Checks if current completed transfer is a write command
            slave_mem[vif.slave_cb.PADDR] = vif.slave_cb.PWDATA; // Saves write data into local associative array RAM
            `uvm_info("SLV_DRV", $sformatf("Local RAM Write Captured: Addr=0x%03h, Data=0x%02h", vif.slave_cb.PADDR, vif.slave_cb.PWDATA), UVM_HIGH) // Prints capture details to console
          end                                            // End write direction handling block
          vif.slave_cb.PREADY <= 1'b0;                   // Deasserts PREADY immediately to prevent multi-cycle handshake issues
        end                                              // End ACCESS phase completion block
      end                                                // End active chip select block
      else begin                                         // Handles idle bus state (no slave selected)
        vif.slave_cb.PREADY <= 1'b0;                     // Holds PREADY deasserted when idle
      end                                                // End idle block
    end                                                  // End of forever loop block
  endtask                                                // End of run phase task declaration

endclass // End of apb_slv_driver class declaration
