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
//   DRIVER PROTOCOL (what this driver does each transaction):
//   ┌─────────────────────────────────────────────────────────────────┐
//   │ 1. Assert transfer=1, drive address/data/read_write           │
//   │ 2. Wait for DUT to complete APB handshake (PENABLE=1,PREADY=1)│
//   │ 3. Capture apb_read_data_out for reads                        │
//   │ 4. Deassert transfer for 1 idle cycle                         │
//   └─────────────────────────────────────────────────────────────────┘
//
//   UVM DRIVER FLOW:
//   The driver sits in a forever loop:
//     seq_item_port.get_next_item(item)  ← blocks until sequencer has an item
//     ... drive the item on the interface ...
//     seq_item_port.item_done()          ← tells sequencer this item is complete
// ============================================================================

// Extends uvm_driver parameterized with our transaction type.
// This gives us the seq_item_port for communicating with the sequencer.
class apb_master_driver extends uvm_driver #(apb_master_seq_item);

  // Register this class with the UVM factory.
  // This enables factory overrides and `type_id::create()`.
  `uvm_component_utils(apb_master_driver)

  // Handle to the virtual interface.
  // "virtual" means this is a pointer to an interface instance (not the instance itself).
  // The actual interface instance lives in tb_top; we get a handle via config_db.
  virtual apb_master_if vif;

  // ---- Constructor ----
  // UVM components always take (name, parent) as constructor arguments.
  // "parent" creates the UVM hierarchy (e.g., agent.drv).
  function new(string name = "apb_master_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase: Get interface handle ----
  // build_phase runs before simulation starts. We use it to retrieve
  // the virtual interface handle that tb_top stored in the config_db.
  // If the handle is not found, `uvm_fatal stops simulation immediately
  // because we can't drive signals without an interface.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_master_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  // =========================================================================
  // UVM RUN PHASE & DRIVING LOOP
  // =========================================================================
  // `run_phase` is the only phase that is defined as a `task` (can consume time)
  // rather than a `function` (must execute in zero time). It starts automatically
  // and executes concurrently across all components.
  //
  // Inside the driver, this task implements a loop that continuously:
  //   1. Waits for a transaction from the sequencer (`get_next_item`).
  //   2. Translates the high-level transaction object into physical pin actions.
  //   3. Signals back when done (`item_done`).
  // =========================================================================
  task run_phase(uvm_phase phase);

    // Synchronize to the clocking block's active clock edge first.
    // NOTE: Many SystemVerilog simulators (like Xcelium) require at least one clocking 
    // block event before you can drive any clocking block output, otherwise you 
    // will get a runtime simulation error.
    @(vif.driver_cb);

    // =========================================================================
    // SYSTEMVERILOG TIP: Non-Blocking Assignments (<=) in Clocking Blocks
    // =========================================================================
    // When driving signals through an interface clocking block (e.g. vif.driver_cb.signal),
    // you MUST use non-blocking assignments (`<=`).
    //
    // Why?
    //   - Clocking blocks are designed to model cycle-accurate synchronous hardware.
    //   - Using `<=` schedules the value change to happen after the clock edge 
    //     (shifted by the output skew defined in the interface, e.g. #1ns).
    //   - If you use blocking assignments (`=`), you bypass the clocking block's
    //     skew logic and risk causing zero-delay delta race conditions where
    //     the design samples the new value on the exact same clock edge.
    // =========================================================================
    vif.driver_cb.transfer        <= 0;  // Initialize to IDLE (no transfer requested)
    vif.driver_cb.READ_WRITE      <= 0;  // Default: write mode
    vif.driver_cb.apb_write_paddr <= 0;  // Clear write address
    vif.driver_cb.apb_read_paddr  <= 0;  // Clear read address
    vif.driver_cb.apb_write_data  <= 0;  // Clear write data

    // Forever loop representing the lifetime of the driver.
    // It will be terminated automatically when UVM drops all objections and kills run_phase.
    forever begin
      apb_master_seq_item item;     // Local reference to the transaction being processed
      int timeout_cnt;              // Safety counter to detect stuck RTL/handshake

      // ── Step 1: Get next transaction from sequencer ──
      // This is a blocking TLM call. It tells the sequencer "I'm ready for work" 
      // and suspends execution of this task until a sequence has an item ready.
      seq_item_port.get_next_item(item);

      // Log the transaction. verbosity UVM_MEDIUM means it prints by default,
      // but can be hidden if we change verbosity to UVM_LOW.
      `uvm_info("DRV", $sformatf("Driving: addr=0x%03h wdata=0x%02h read=%0b",
                                  item.addr, item.wdata, item.read), UVM_MEDIUM)

      // ── Step 2: Drive system-side inputs ──
      // Wait for next clock edge, then assert the signals.
      @(vif.driver_cb);
      vif.driver_cb.transfer   <= 1;          // Tell DUT: "I want a transfer"
      vif.driver_cb.READ_WRITE <= item.read;  // Tell DUT: read or write?
      if (item.read) begin
        // For reads: drive the read address port
        vif.driver_cb.apb_read_paddr <= item.addr;
      end
      else begin
        // For writes: drive both write address and write data ports
        vif.driver_cb.apb_write_paddr <= item.addr;
        vif.driver_cb.apb_write_data  <= item.wdata;
      end

      // ── Step 3: Wait for the DUT's APB transfer to complete ──
      // The DUT's FSM goes: IDLE → SETUP → ENABLE
      // The slave responder drives PREADY=1 when PENABLE=1 (zero wait-state).
      // We poll PREADY each clock cycle until it goes high.
      // A timeout counter prevents hanging if the DUT is stuck.
      timeout_cnt = 0;
      do begin
        @(vif.driver_cb);          // Wait one clock cycle
        timeout_cnt++;
        if (timeout_cnt > 20) begin
          `uvm_error("DRV", "Timeout waiting for PREADY!")
          break;                   // Break out to avoid infinite hang
        end
      end while (!vif.driver_cb.PREADY);  // Loop until PREADY=1

      // ── Step 4: Capture outputs ──
      // After the transfer completes, capture the results.
      if (item.read)
        item.rdata = vif.driver_cb.apb_read_data_out;  // Grab read data
      item.pslverr = vif.driver_cb.PSLVERR;             // Grab error flag

      // ── Step 5: Idle gap ──
      // Deassert transfer IMMEDIATELY after PREADY detection.
      // If we wait an extra cycle, the DUT sees transfer=1 in ENABLE
      // and starts a second back-to-back transfer with the same data.
      vif.driver_cb.transfer <= 0;  // Release transfer request
      @(vif.driver_cb);             // Wait one cycle for DUT to return to IDLE

      // ── Step 6: Signal completion ──
      // Tell the sequencer that we're done with this item.
      // This unblocks the sequence's finish_item() call so it can
      // send the next item.
      seq_item_port.item_done();
    end
  endtask

endclass
