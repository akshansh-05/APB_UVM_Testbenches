// =============================================================================
// FILE: apb_slv_driver.sv
// DESCRIPTION:
//   APB Slave Driver — the REACTIVE driver in the slave-side agent.
//
//   Since we are verifying an APB Master DUT, there is no physical slave in
//   the design. This driver EMULATES a memory-mapped APB slave by:
//     1. Monitoring the bus for PSEL assertion (indicating the master selected this slave)
//     2. Responding with PREADY to complete the APB handshake
//     3. Storing write data into a local associative array (acting as slave RAM)
//     4. Returning previously stored data (or a fallback pattern) for read transfers
//
//   SIGNALS DRIVEN (via slave_cb clocking block):
//     - PREADY : Assert 1 when slave is ready to complete the transfer
//     - PRDATA : Drive read data back onto the bus during read transfers
//
//   REACTIVE BEHAVIOR (no sequencer needed):
//     Unlike the system driver, this driver does NOT pull transactions from a
//     sequencer. Instead, it continuously monitors the bus and reacts to whatever
//     the master DUT puts on the PSEL/PENABLE/PADDR/PWRITE/PWDATA lines.
//
//   MEMORY MODEL:
//     - slave_mem: associative array indexed by 9-bit address
//     - On write: stores PWDATA into slave_mem[PADDR]
//     - On read: returns slave_mem[PADDR] if address was previously written,
//                otherwise returns fallback pattern: PADDR[7:0] XOR 0xA5
//     - The scoreboard knows this fallback pattern and uses it for comparison
//
//   APB HANDSHAKE RESPONSE TIMING:
//     SETUP phase (PSEL=1, PENABLE=0): Slave asserts PREADY=1 (zero wait states)
//                                       If read: drives PRDATA with stored/fallback data
//     ACCESS phase (PSEL=1, PENABLE=1, PREADY=1): Handshake completes
//                                       If write: captures PWDATA into slave_mem
//                                       Deasserts PREADY=0
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_slv_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_slv_driver)    // Register with UVM factory

  virtual apb_if vif;                     // Virtual interface handle

  // ---------------------------------------------------------------------------
  // LOCAL SLAVE MEMORY
  // Associative array acting as the slave's RAM. Indexed by 9-bit address,
  // storing 8-bit data. Only addresses that have been written to will exist
  // in this array; unwritten addresses will use the fallback XOR pattern.
  // ---------------------------------------------------------------------------
  protected bit [7:0] slave_mem [bit [8:0]];

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_slv_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE
  // Retrieve virtual interface handle from config_db (same as sys_driver).
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SLV_DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  // ---------------------------------------------------------------------------
  // RUN PHASE — reactive slave responder loop
  //
  // The slave driver waits for reset to deassert, then continuously monitors
  // the APB bus signals every clock cycle and responds according to the
  // APB protocol:
  //
  //   1. If no slave is selected (PSEL1=0 AND PSEL2=0), keep PREADY=0
  //   2. If a slave is selected during SETUP phase (PENABLE=0):
  //      - Assert PREADY=1 (we respond with zero wait states)
  //      - For reads: prepare PRDATA from slave_mem or fallback pattern
  //   3. If handshake completes during ACCESS phase (PENABLE=1, PREADY=1):
  //      - For writes: capture PWDATA into slave_mem[PADDR]
  //      - Deassert PREADY=0 to end the handshake
  //
  //   IMPORTANT: We also check 'vif.transfer' (raw wire, not clocking block)
  //   to filter out dummy SETUP cycles. The master DUT can linger in SETUP
  //   state for one cycle after a transaction completes when 'transfer' has
  //   already dropped — we must NOT respond to those phantom cycles.
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    // Wait for reset to deassert before starting reactive behavior
    wait(vif.PRESETn === 1'b1);

    // Initialize slave response signals to idle state
    @(vif.slave_cb);
    vif.slave_cb.PREADY <= 1'b0;
    vif.slave_cb.PRDATA <= 8'h00;

    forever begin
      @(vif.slave_cb);    // Sample bus signals on every rising clock edge

      // -----------------------------------------------------------------------
      // ACTIVE TRANSFER: A slave is selected AND the system is requesting a transfer
      // We check 'vif.transfer' (raw wire) to filter phantom SETUP cycles
      // -----------------------------------------------------------------------
      if (vif.transfer && (vif.slave_cb.PSEL1 || vif.slave_cb.PSEL2)) begin

        // --- SETUP PHASE: PENABLE is low ---
        // The master has asserted PSEL and placed address/control on the bus.
        // We respond by asserting PREADY and preparing read data if needed.
        if (!vif.slave_cb.PENABLE) begin
          vif.slave_cb.PREADY <= 1'b1;    // Zero wait-state: ready immediately

          // For read transfers: prepare PRDATA from local memory
          if (!vif.slave_cb.PWRITE) begin
            if (slave_mem.exists(vif.slave_cb.PADDR)) begin
              // Address was previously written — return the stored data
              vif.slave_cb.PRDATA <= slave_mem[vif.slave_cb.PADDR];
              `uvm_info("SLV_DRV", $sformatf("Local RAM Read Hit: Addr=0x%03h, Data=0x%02h", vif.slave_cb.PADDR, slave_mem[vif.slave_cb.PADDR]), UVM_HIGH)
            end
            else begin
              // Address was never written — return fallback pattern
              // Fallback: lower 8 bits of address XOR'd with 0xA5
              // The scoreboard knows this pattern and expects it for unwritten addresses
              bit [7:0] fallback_data = vif.slave_cb.PADDR[7:0] ^ 8'hA5;
              vif.slave_cb.PRDATA <= fallback_data;
              `uvm_info("SLV_DRV", $sformatf("Local RAM Read Miss: Addr=0x%03h, Fallback Data=0x%02h", vif.slave_cb.PADDR, fallback_data), UVM_HIGH)
            end
          end
        end

        // --- ACCESS PHASE: PENABLE is high AND PREADY is high ---
        // The handshake completes in this cycle. Capture write data and deassert PREADY.
        // NOTE: We read 'vif.PREADY' (raw interface signal) instead of
        //       'vif.slave_cb.PREADY' because clocking block outputs cannot
        //       be used as rvalues (read) — this avoids compiler warnings/errors.
        else if (vif.slave_cb.PENABLE && vif.PREADY) begin
          // For write transfers: store the data into our local slave memory
          if (vif.slave_cb.PWRITE) begin
            slave_mem[vif.slave_cb.PADDR] = vif.slave_cb.PWDATA;
            `uvm_info("SLV_DRV", $sformatf("Local RAM Write Captured: Addr=0x%03h, Data=0x%02h", vif.slave_cb.PADDR, vif.slave_cb.PWDATA), UVM_HIGH)
          end
          // Deassert PREADY to signal end of current transfer
          vif.slave_cb.PREADY <= 1'b0;
        end
      end
      // -----------------------------------------------------------------------
      // IDLE: No slave selected — keep PREADY deasserted
      // -----------------------------------------------------------------------
      else begin
        vif.slave_cb.PREADY <= 1'b0;
      end
    end
  endtask

endclass
