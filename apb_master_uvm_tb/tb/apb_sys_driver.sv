// =============================================================================
// FILE: apb_sys_driver.sv
// DESCRIPTION:
//   APB System Driver — the ACTIVE driver in the system-side agent.
//
//   This driver sits on the "host/processor" side of the APB Master Bridge DUT.
//   It consumes apb_seq_item transactions from the sequencer and drives them
//   onto the DUT's system-side input ports to initiate APB bus transfers.
//
//   SIGNALS DRIVEN (via master_cb clocking block):
//     - transfer         : Assert 1 to initiate a transfer, deassert 0 when done
//     - READ_WRITE       : 0=Write, 1=Read
//     - apb_write_paddr  : Write target address (driven for write transactions)
//     - apb_read_paddr   : Read target address (driven for read transactions)
//     - apb_write_data   : Write data payload (driven for write transactions)
//
//   HANDSHAKE MECHANISM:
//     After driving the request signals, the driver polls PREADY each clock
//     cycle. When PREADY goes high, the APB handshake is complete:
//       - For reads: captures apb_read_data_out (the data returned by DUT)
//       - For all: captures PSLVERR status
//     Then deasserts 'transfer' and calls item_done() to release the sequencer.
//
//   TIMEOUT PROTECTION:
//     A 20-cycle timeout counter prevents the simulation from hanging if
//     the slave never responds with PREADY.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_sys_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_sys_driver)    // Register with UVM factory for type overrides

  virtual apb_if vif;                     // Virtual interface handle — set via config_db

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_sys_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE
  // Retrieve the virtual interface handle from the UVM configuration database.
  // The handle was registered by tb_top using:
  //   uvm_config_db #(virtual apb_if)::set(null, "*", "vif", apb_vif);
  // If not found, simulation terminates with UVM_FATAL.
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  // ---------------------------------------------------------------------------
  // RUN PHASE — main simulation driving loop
  //
  // Flow for each transaction:
  //   1. Wait for first clock edge to synchronize
  //   2. Initialize all system-side signals to idle state (transfer=0)
  //   3. Enter forever loop:
  //      a. Pull next transaction from sequencer (blocking call)
  //      b. Drive request signals onto interface via clocking block
  //      c. Poll PREADY with timeout until handshake completes
  //      d. Capture response data (rdata for reads, pslverr for all)
  //      e. Deassert transfer and signal item_done()
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    // Synchronize to the first rising clock edge before driving anything
    @(vif.master_cb);

    // Initialize all system-side signals to idle/zero state
    // This ensures the DUT sees clean inputs before the first transaction
    vif.master_cb.transfer        <= 0;
    vif.master_cb.READ_WRITE      <= 0;
    vif.master_cb.apb_write_paddr <= 0;
    vif.master_cb.apb_read_paddr  <= 0;
    vif.master_cb.apb_write_data  <= 0;

    forever begin
      apb_seq_item item;
      int timeout_cnt;    // Counter to detect hung simulation (no PREADY response)

      // STEP 1: Blocking call — waits until the sequencer has a transaction ready
      seq_item_port.get_next_item(item);

      `uvm_info("DRV", $sformatf("Driving: addr=0x%03h wdata=0x%02h read=%0b", item.addr, item.wdata, item.read), UVM_MEDIUM)

      // STEP 2: Drive the request signals onto the DUT's system-side inputs
      // Assert 'transfer' to tell the DUT to start an APB bus transaction
      vif.master_cb.transfer   <= 1;
      vif.master_cb.READ_WRITE <= item.read;    // 0=Write, 1=Read

      // Drive the appropriate address and data based on transfer direction
      if (item.read) begin
        vif.master_cb.apb_read_paddr <= item.addr;   // Read address
      end
      else begin
        vif.master_cb.apb_write_paddr <= item.addr;   // Write address
        vif.master_cb.apb_write_data  <= item.wdata;   // Write data payload
      end

      // STEP 3: Wait for the APB handshake to complete (PREADY goes high)
      // The DUT will transition through IDLE→SETUP→ENABLE, and the slave
      // driver will assert PREADY when it's ready to complete the transfer.
      timeout_cnt = 0;
      do begin
        @(vif.master_cb);                   // Wait one clock cycle
        timeout_cnt++;
        if (timeout_cnt > 20) begin         // Safety: abort after 20 cycles
          `uvm_error("DRV", "Timeout waiting for PREADY!")
          break;
        end
      end while (!vif.master_cb.PREADY);    // Exit when PREADY asserted

      // STEP 4: Capture response data from the DUT
      if (item.read)
        item.rdata = vif.master_cb.apb_read_data_out;  // Capture read data for scoreboard
      item.pslverr = vif.master_cb.PSLVERR;            // Capture error status

      // STEP 5: Deassert transfer to return to idle state
      vif.master_cb.transfer <= 0;
      @(vif.master_cb);    // Wait one cycle for the deassert to propagate

      // STEP 6: Signal the sequencer that this transaction is complete
      // This unblocks the sequence's finish_item() call
      seq_item_port.item_done();
    end
  endtask

endclass
