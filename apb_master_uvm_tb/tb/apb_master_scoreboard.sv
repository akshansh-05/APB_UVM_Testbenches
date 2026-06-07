// ============================================================================
// FILE: apb_master_scoreboard.sv
// DESCRIPTION:
//   Scoreboard for the APB Master Bridge testbench.
//
//   The scoreboard is the CHECKER — it receives observed transactions from
//   the monitor and verifies that the DUT behaved correctly.
//
//   KEY DIFFERENCE FROM SLAVE TB:
//   The slave scoreboard checked read data against a reference memory.
//   The master scoreboard checks that the master DUT correctly:
//     1. Routes transfers to the right slave (PSEL1 vs PSEL2 based on addr[8])
//     2. Generates correct APB signals (PADDR, PWRITE, PWDATA)
//     3. Returns correct read data (apb_read_data_out)
//     4. Reports no false errors (PSLVERR should be 0 for valid transfers)
//
//   SELF-CONSISTENCY CHECKING:
//   We use the OBSERVED APB signals to check internal consistency.
//   For example: if PADDR[8]=0, then PSEL1 must be 1 and PSEL2 must be 0.
//
//   For reads, the slave responder in tb_top drives a predictable pattern:
//     PRDATA = PADDR[7:0] XOR 0xA5
//   So we can verify: apb_read_data_out == PADDR[7:0] ^ 0xA5
//
//   DATA FLOW:
//   Monitor ──(analysis port)──→ Scoreboard.write(item)
//   The write() function is called automatically whenever the monitor
//   broadcasts a transaction via ap.write(item).
// ============================================================================

// Extends uvm_scoreboard, which is a base class for checking components.
class apb_master_scoreboard extends uvm_scoreboard;

  // Register with UVM factory.
  `uvm_component_utils(apb_master_scoreboard)

  // ---- Analysis Implementation Port ----
  // uvm_analysis_imp is the RECEIVING end of an analysis connection.
  // It implements a write() function that gets called when the monitor
  // broadcasts a transaction.
  //
  // Template parameters:
  //   apb_master_seq_item    → the transaction type we receive
  //   apb_master_scoreboard  → the class that implements write()
  //
  // This port is connected to the monitor's analysis port in apb_master_env.sv:
  //   agent.mon.ap.connect(scoreboard.analysis_export)
  uvm_analysis_imp #(apb_master_seq_item, apb_master_scoreboard) analysis_export;

  // ---- Counters for tracking test results ----
  int num_writes     = 0;   // Number of write transactions observed
  int num_reads      = 0;   // Number of read transactions observed
  int num_passes     = 0;   // Number of checks that passed
  int num_errors     = 0;   // Number of checks that failed

  // ---- Constructor ----
  function new(string name = "apb_master_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase ----
  // Create the analysis implementation port.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // ---- Write Method ----
  // This function is called AUTOMATICALLY every time the monitor broadcasts
  // a transaction via its analysis port. The "item" parameter contains the
  // observed APB bus values captured by the monitor.
  //
  // We perform 4 checks on each transaction:
  //   CHECK 1: PSEL routing (is the correct slave selected?)
  //   CHECK 2: PSLVERR status (should be 0 for valid transfers)
  //   CHECK 3: PENABLE status (should be 1 during completed transfers)
  //   CHECK 4: Read data verification (for read transactions only)
  function void write(apb_master_seq_item item);

    bit [7:0] expected_rdata;    // What we expect the read data to be
    bit       expected_psel1;    // What we expect PSEL1 to be
    bit       expected_psel2;    // What we expect PSEL2 to be

    // ===============================================================
    // CHECK 1: PSEL Routing
    // ===============================================================
    // The master uses PADDR[8] to select which slave to talk to:
    //   PADDR[8] = 0 → Slave 1 → PSEL1=1, PSEL2=0
    //   PADDR[8] = 1 → Slave 2 → PSEL1=0, PSEL2=1
    expected_psel1 = ~item.paddr[8];   // PSEL1 is active when addr[8]=0
    expected_psel2 =  item.paddr[8];   // PSEL2 is active when addr[8]=1

    if (item.psel1 !== expected_psel1 || item.psel2 !== expected_psel2) begin
      num_errors++;
      `uvm_error("SCB", $sformatf(
        "PSEL ROUTING FAIL: paddr=0x%03h -> expected PSEL1=%0b PSEL2=%0b, got PSEL1=%0b PSEL2=%0b",
        item.paddr, expected_psel1, expected_psel2, item.psel1, item.psel2))
    end
    else begin
      num_passes++;
      `uvm_info("SCB", $sformatf(
        "PSEL ROUTING PASS: paddr=0x%03h -> PSEL1=%0b PSEL2=%0b",
        item.paddr, item.psel1, item.psel2), UVM_MEDIUM)
    end

    // ===============================================================
    // CHECK 2: PSLVERR should be 0 for valid transfers
    // ===============================================================
    // Our slave responder in tb_top never generates errors, and
    // our constrained random addresses are valid, so PSLVERR should
    // always be 0. If it's 1, something went wrong in the DUT.
    if (item.pslverr !== 0) begin
      num_errors++;
      `uvm_error("SCB", $sformatf(
        "PSLVERR FAIL: paddr=0x%03h pslverr=%0b (expected 0 for valid transfer)",
        item.paddr, item.pslverr))
    end
    else begin
      num_passes++;
      `uvm_info("SCB", $sformatf(
        "PSLVERR PASS: paddr=0x%03h pslverr=0", item.paddr), UVM_MEDIUM)
    end

    // ===============================================================
    // CHECK 3: PENABLE should be 1 during a completed transfer
    // ===============================================================
    // The monitor only captures transactions when PENABLE=1 && PREADY=1,
    // so PENABLE should always be 1 here. This is a sanity check that
    // the DUT correctly asserted PENABLE during the ACCESS phase.
    if (item.penable !== 1) begin
      num_errors++;
      `uvm_error("SCB", $sformatf(
        "PENABLE FAIL: paddr=0x%03h penable=%0b (expected 1 during ACCESS phase)",
        item.paddr, item.penable))
    end
    else begin
      num_passes++;
      `uvm_info("SCB", $sformatf(
        "PENABLE PASS: paddr=0x%03h penable=1", item.paddr), UVM_MEDIUM)
    end

    // ===============================================================
    // CHECK 4: Read Data Verification
    // ===============================================================
    // For reads (PWRITE=0), the slave responder in tb_top drives:
    //   PRDATA = PADDR[7:0] XOR 0xA5
    // The master should pass this through to apb_read_data_out unchanged.
    // So we expect: rdata == paddr[7:0] ^ 0xA5
    //
    // Example: addr=0x010 → PRDATA = 0x10 ^ 0xA5 = 0xB5
    if (!item.pwrite) begin
      // This is a READ transaction (PWRITE=0 means read in APB)
      num_reads++;
      expected_rdata = item.paddr[7:0] ^ 8'hA5;  // Calculate expected read data

      if (item.rdata === expected_rdata) begin
        num_passes++;
        `uvm_info("SCB", $sformatf(
          "READ DATA PASS: paddr=0x%03h expected_rdata=0x%02h got_rdata=0x%02h",
          item.paddr, expected_rdata, item.rdata), UVM_MEDIUM)
      end
      else begin
        num_errors++;
        `uvm_error("SCB", $sformatf(
          "READ DATA FAIL: paddr=0x%03h expected_rdata=0x%02h got_rdata=0x%02h",
          item.paddr, expected_rdata, item.rdata))
      end
    end
    else begin
      // This is a WRITE transaction (PWRITE=1 means write in APB)
      num_writes++;
      `uvm_info("SCB", $sformatf(
        "WRITE observed: paddr=0x%03h pwdata=0x%02h", item.paddr, item.pwdata), UVM_MEDIUM)
    end

  endfunction

  // ---- Report Phase: Final summary ----
  // report_phase runs at the end of simulation, after all run_phase tasks
  // have completed. We print a summary of all checks.
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", "================================================", UVM_LOW)
    `uvm_info("SCB", "       APB MASTER SCOREBOARD SUMMARY", UVM_LOW)
    `uvm_info("SCB", "================================================", UVM_LOW)
    `uvm_info("SCB", $sformatf("  Write Transactions : %0d", num_writes), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Read Transactions  : %0d", num_reads), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Checks Passed: %0d", num_passes), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Checks Failed: %0d", num_errors), UVM_LOW)
    `uvm_info("SCB", "================================================", UVM_LOW)
    if (num_errors == 0)
      `uvm_info("SCB", "  RESULT: ALL CHECKS PASSED", UVM_LOW)
    else
      `uvm_error("SCB", $sformatf("  RESULT: %0d CHECKS FAILED", num_errors))
  endfunction

endclass
