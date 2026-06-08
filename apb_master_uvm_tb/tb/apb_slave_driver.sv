// ============================================================================
// FILE: apb_slave_driver.sv
// DESCRIPTION:
//   A standalone UVM component that emulates the APB Slave.
//   It monitors the APB bus signals from the Master DUT and dynamically
//   drives the slave response signals (PREADY, PRDATA).
//   It is placed directly in the environment (outside the agent).
//
//   UVM CONCEPTS DEMONSTRATED:
//     1. uvm_component:
//        Unlike transient objects, components are built at the start of
//        simulation and remain active throughout. They participate in the UVM
//        phases (build, connect, run, etc.).
//     2. Config DB (uvm_config_db):
//        Retrieves virtual interface handles (`vif`) and shared objects 
//        (`mem_model`) from the configuration database.
//     3. Non-Blocking Assignments (<=) in Clocking Blocks:
//        All outputs driven through a clocking block must use `<=` to prevent 
//        delta-cycle race conditions.
// ============================================================================

`ifndef APB_SLAVE_DRIVER_SV
`define APB_SLAVE_DRIVER_SV

class apb_slave_driver extends uvm_component;

  // Register with UVM factory
  `uvm_component_utils(apb_slave_driver)

  // Handle to the virtual interface (contains clocking blocks and modports)
  virtual apb_master_if vif;

  // Handle to the shared memory model (RAM storage)
  apb_memory_model mem_model;

  // ---- Constructor ----
  // Standard constructor for UVM components.
  // Take two arguments: component name, and a pointer to the parent component.
  function new(string name = "apb_slave_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase ----
  // Executed automatically at the beginning of the simulation.
  // This is used to instantiate child components or retrieve configurations from DB.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Retrieve virtual interface from the global configuration database.
    // The key "vif" was set in tb_top.sv.
    if (!uvm_config_db #(virtual apb_master_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("SLV_DRV", "Could not get virtual interface 'vif' from config_db")
    end
    
    // Retrieve the shared memory model.
    // This allows the driver to read and write to the same RAM storage as the scoreboard.
    if (!uvm_config_db #(apb_memory_model)::get(this, "", "mem_model", mem_model)) begin
      `uvm_warning("SLV_DRV", "Could not get shared memory model 'mem_model' from config_db, using local fallback")
    end
  endfunction

  // =========================================================================
  // UVM RUN PHASE: REACTIVE RESPONDER LOOP
  // =========================================================================
  // Unlike the master driver (which is driven by sequences via a sequencer),
  // a slave driver is a PASSIVE RESPONDER (or reactive driver).
  //
  // It operates on a reactive loop:
  //   1. It continuously monitors the APB bus interface pins.
  //   2. When it sees that the master selected this slave (PSEL is high),
  //      it reactively drives the slave response pins (PREADY, PRDATA)
  //      to emulate a real hardware memory.
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    // Wait for reset to be released (PRESETn goes high) before initiating drive.
    wait(vif.PRESETn === 1'b1);
    
    // Synchronize with the clocking block edge to align with the first active clock.
    @(vif.slave_cb);
    
    // Initialize slave signals (default state: not ready, data bus low)
    vif.slave_cb.PREADY <= 1'b0;
    vif.slave_cb.PRDATA <= 8'h00;
    
    // Main reactive loop: runs forever to respond to APB transactions.
    forever begin
      @(vif.slave_cb); // Wait for the next rising clock edge (inputs sampled here)
      
      // Check if a transfer is active (either Slave 1 or Slave 2 select line is high)
      if (vif.slave_cb.PSEL1 || vif.slave_cb.PSEL2) begin
        
        // ─────────────────────────────────────────────────────────────────────
        // CASE 1: SETUP Phase (PSEL is high, but PENABLE is low)
        // ─────────────────────────────────────────────────────────────────────
        // The SETUP phase is the first clock cycle of any APB transfer.
        // During SETUP, the master places the address and direction on the bus.
        //
        // In a zero-wait-state slave:
        //   - We must drive PREADY high during the *next* cycle (ACCESS phase).
        //   - By assigning `PREADY <= 1` during the SETUP phase, the simulator
        //     queues the update to occur at the next clock edge.
        //   - For reads, we must also place the data on the read data bus (PRDATA)
        //     during SETUP so it is stable when the master samples it in the ACCESS phase.
        // ─────────────────────────────────────────────────────────────────────
        if (!vif.slave_cb.PENABLE) begin
          vif.slave_cb.PREADY <= 1'b1; // Drive PREADY high for the upcoming ACCESS phase (zero wait-states)
          
          if (!vif.slave_cb.PWRITE) begin
            // Read transaction: retrieve data from the shared memory model
            bit [7:0] rdata;
            if (mem_model != null && mem_model.read_ram(vif.slave_cb.PADDR, rdata)) begin
              vif.slave_cb.PRDATA <= rdata; // Drive read data from memory
              `uvm_info("SLV_DRV", $sformatf("Read Hit: Addr=0x%03h, Data=0x%02h", vif.slave_cb.PADDR, rdata), UVM_HIGH)
            end
            else begin
              // Fallback to address-xor pattern if address has never been written
              bit [7:0] fallback_data = vif.slave_cb.PADDR[7:0] ^ 8'hA5;
              vif.slave_cb.PRDATA <= fallback_data;
              `uvm_info("SLV_DRV", $sformatf("Read Miss (using fallback): Addr=0x%03h, Data=0x%02h", vif.slave_cb.PADDR, fallback_data), UVM_HIGH)
            end
          end
        end
        
        // ─────────────────────────────────────────────────────────────────────
        // CASE 2: ACCESS Phase Completion (PSEL, PENABLE and PREADY are all high)
        // ─────────────────────────────────────────────────────────────────────
        // The ACCESS phase is the second clock cycle of the APB transfer.
        // When PREADY is high at the rising clock edge, the transfer is complete.
        //
        // Actions:
        //   - If it's a WRITE transaction, we capture the data on the bus (PWDATA)
        //     and write it to our memory model.
        //   - Deassert PREADY immediately to prevent extending the transfer
        //     or responding to the next cycle prematurely.
        // ─────────────────────────────────────────────────────────────────────
        else if (vif.slave_cb.PENABLE && vif.slave_cb.PREADY) begin
          if (vif.slave_cb.PWRITE) begin
            // Write transaction: save PWDATA into memory model
            if (mem_model != null) begin
              mem_model.write(vif.slave_cb.PADDR, vif.slave_cb.PWDATA);
            end
            `uvm_info("SLV_DRV", $sformatf("Write Captured: Addr=0x%03h, Data=0x%02h", vif.slave_cb.PADDR, vif.slave_cb.PWDATA), UVM_HIGH)
          end
          vif.slave_cb.PREADY <= 1'b0; // Deassert PREADY for the next cycle
        end
        
      end
      // ─────────────────────────────────────────────────────────────────────
      // CASE 3: IDLE State (No slave is selected)
      // ─────────────────────────────────────────────────────────────────────
      else begin
        vif.slave_cb.PREADY <= 1'b0; // Ensure PREADY is deasserted when idle
      end
    end
  endtask

endclass

`endif // APB_SLAVE_DRIVER_SV
