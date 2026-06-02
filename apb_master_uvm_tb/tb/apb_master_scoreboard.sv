// ============================================================================
// FILE: apb_master_scoreboard.sv
// DESCRIPTION:
//   Scoreboard for the APB Master Bridge testbench.
//
//   KEY DIFFERENCE FROM SLAVE TB:
//   The slave scoreboard checked read data against a reference memory.
//   The master scoreboard checks that the master DUT correctly:
//     1. Routes transfers to the right slave (PSEL1 vs PSEL2)
//     2. Generates correct APB signals (PADDR, PWRITE, PWDATA)
//     3. Returns correct read data (apb_read_data_out)
//     4. Reports no false errors (PSLVERR)
//
//   SELF-CONSISTENCY CHECKING:
//   We use the OBSERVED APB signals to check internal consistency.
//   For example: if PADDR[8]=0, then PSEL1 must be 1 and PSEL2 must be 0.
//
//   For reads, the slave responder in tb_top drives a predictable pattern:
//     PRDATA = PADDR[7:0] XOR 0xA5
//   So we can verify: apb_read_data_out == PADDR[7:0] ^ 0xA5
// ============================================================================

class apb_master_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(apb_master_scoreboard)

  // Analysis implementation port — receives items from the monitor
  uvm_analysis_imp #(apb_master_seq_item, apb_master_scoreboard) analysis_export;

  // ---- Counters ----
  int num_writes     = 0;
  int num_reads      = 0;
  int num_passes     = 0;
  int num_errors     = 0;

  // ---- Constructor ----
  function new(string name = "apb_master_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // ---- Write Method: Called when monitor broadcasts a transaction ----
  function void write(apb_master_seq_item item);

    bit [7:0] expected_rdata;
    bit       expected_psel1;
    bit       expected_psel2;

    // ===============================================================
    // CHECK 1: PSEL Routing
    // If PADDR[8]=0, slave 1 should be selected (PSEL1=1, PSEL2=0)
    // If PADDR[8]=1, slave 2 should be selected (PSEL1=0, PSEL2=1)
    // ===============================================================
    expected_psel1 = ~item.paddr[8];
    expected_psel2 =  item.paddr[8];

    if (item.psel1 !== expected_psel1 || item.psel2 !== expected_psel2) begin
      num_errors++;
      `uvm_error("SCB", $sformatf(
        "PSEL ROUTING FAIL: paddr=0x%03h → expected PSEL1=%0b PSEL2=%0b, got PSEL1=%0b PSEL2=%0b",
        item.paddr, expected_psel1, expected_psel2, item.psel1, item.psel2))
    end
    else begin
      num_passes++;
      `uvm_info("SCB", $sformatf(
        "PSEL ROUTING PASS: paddr=0x%03h → PSEL1=%0b PSEL2=%0b",
        item.paddr, item.psel1, item.psel2), UVM_MEDIUM)
    end

    // ===============================================================
    // CHECK 2: PSLVERR should be 0 for valid transfers
    // ===============================================================
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
    // CHECK 3: Read Data Verification
    // For reads (PWRITE=0), the slave responder drives:
    //   PRDATA = PADDR[7:0] XOR 0xA5
    // The master should pass this through to apb_read_data_out.
    // ===============================================================
    if (!item.pwrite) begin
      // This is a read transaction
      num_reads++;
      expected_rdata = item.paddr[7:0] ^ 8'hA5;

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
      // This is a write transaction
      num_writes++;
      `uvm_info("SCB", $sformatf(
        "WRITE observed: paddr=0x%03h pwdata=0x%02h", item.paddr, item.pwdata), UVM_MEDIUM)
    end

  endfunction

  // ---- Report Phase: Final summary ----
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
