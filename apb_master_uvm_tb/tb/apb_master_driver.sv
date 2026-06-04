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

  // ---- Run Phase: Main driving loop ----
  // run_phase is a task (not function) because it runs for the entire simulation.
  // It executes concurrently with the monitor's run_phase.
  task run_phase(uvm_phase phase);

    // Wait for the first clock edge before driving clocking-block outputs.
    // Xcelium requires at least one clock edge before you can drive a
    // clocking block output, otherwise it throws a runtime error.
    @(vif.driver_cb);

    // Initialize all system-side signals to idle state (no transfer requested).
    // Using NBA (<=) because we're driving through a clocking block.
    vif.driver_cb.transfer        <= 0;  // No transfer active
    vif.driver_cb.READ_WRITE      <= 0;  // Default: write mode
    vif.driver_cb.apb_write_paddr <= 0;  // Clear write address
    vif.driver_cb.apb_read_paddr  <= 0;  // Clear read address
    vif.driver_cb.apb_write_data  <= 0;  // Clear write data

    // Main driving loop — runs forever until simulation ends.
    // Each iteration processes one transaction from the sequencer.
    forever begin
      apb_master_seq_item item;     // Local handle for the current transaction
      int timeout_cnt;              // Counter to detect stuck DUT

      // ── Step 1: Get next transaction from sequencer ──
      // This BLOCKS until the sequencer has an item ready.
      // The item comes from a sequence's start_item()/finish_item() call.
      seq_item_port.get_next_item(item);

      // Log what we're about to drive (visible at UVM_MEDIUM verbosity)
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
      // Deassert transfer for 1 cycle so the DUT FSM returns to IDLE
      // before the next transaction. Without this gap, the DUT might
      // interpret consecutive transfers incorrectly.
      @(vif.driver_cb);
      vif.driver_cb.transfer <= 0;  // Release transfer request
      @(vif.driver_cb);             // Wait one more cycle in IDLE state

      // ── Step 6: Signal completion ──
      // Tell the sequencer that we're done with this item.
      // This unblocks the sequence's finish_item() call so it can
      // send the next item.
      seq_item_port.item_done();
    end
  endtask

endclass
