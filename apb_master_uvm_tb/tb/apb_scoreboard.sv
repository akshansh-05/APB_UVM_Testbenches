// =============================================================================
// FILE: apb_scoreboard.sv
// DESCRIPTION:
//   APB Scoreboard — the central verification checker that compares EXPECTED
//   system-side requests against ACTUAL APB bus transactions.
//
//   ARCHITECTURE:
//     The scoreboard has TWO analysis ports (using `uvm_analysis_imp_decl`):
//       1. exp_port (expected) — receives items from apb_sys_monitor
//          → Triggers write_expected(): queues the item and updates ref_mem
//       2. act_port (actual)   — receives items from apb_monitor
//          → Triggers write_actual(): pops from queue and runs all checks
//
//   VERIFICATION STRATEGY:
//     For each completed bus transaction, the scoreboard performs these checks:
//       ┌─────────────────────────────────────────────────────────────────────┐
//       │ CHECK 1: DIRECTION — pwrite on bus matches ~read from system      │
//       │ CHECK 2: ADDRESS   — paddr on bus matches addr from system        │
//       │ CHECK 3: WRITE DATA— pwdata on bus matches wdata from system      │
//       │ CHECK 4: SLAVE SEL — PSEL1/PSEL2 correct based on addr[8]        │
//       │ CHECK 5: READ DATA — PRDATA matches ref_mem or fallback pattern   │
//       │ CHECK 6: SYS READ  — system read_data_out matches bus PRDATA      │
//       │ CHECK 7: PENABLE   — must be 1 during completed handshake        │
//       │ CHECK 8: PSLVERR   — must be 0 for normal operation             │
//       └─────────────────────────────────────────────────────────────────────┘
//
//   REFERENCE MEMORY (ref_mem):
//     An associative array that mirrors what the slave should contain.
//     On write_expected(): if the system requested a write, store ref_mem[addr]=wdata
//     On write_actual() read check: compare bus rdata against ref_mem[paddr]
//     If the address was never written, expect the fallback: addr[7:0] ^ 0xA5
//
//   REPORT PHASE:
//     At the end of simulation, prints a summary of all checks passed/failed
//     with a clear PASS/FAIL verdict.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// Suffix declarations to create two analysis implementation ports of the same type.
// _expected and _actual suffixes generate write_expected() and write_actual() methods.
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class apb_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(apb_scoreboard)    // Register with UVM factory

  // ---------------------------------------------------------------------------
  // ANALYSIS PORTS — two ports for receiving expected and actual transactions
  // ---------------------------------------------------------------------------
  uvm_analysis_imp_expected #(apb_seq_item, apb_scoreboard) exp_port;  // From sys_monitor
  uvm_analysis_imp_actual   #(apb_seq_item, apb_scoreboard) act_port;  // From bus monitor

  // ---------------------------------------------------------------------------
  // STATISTICS COUNTERS — track verification results for report_phase summary
  // ---------------------------------------------------------------------------
  int num_writes     = 0;    // Count of write transactions verified
  int num_reads      = 0;    // Count of read transactions verified
  int num_passes     = 0;    // Count of individual assertions that passed
  int num_errors     = 0;    // Count of individual assertions that failed

  // ---------------------------------------------------------------------------
  // REFERENCE MEMORY — mirrors expected slave memory contents
  // Updated on every write transaction, consulted on every read transaction
  // ---------------------------------------------------------------------------
  protected bit [7:0] ref_mem [bit [8:0]];    // Associative array: addr → data

  // ---------------------------------------------------------------------------
  // EXPECTED TRANSACTION QUEUE — FIFO ordering for in-order comparison
  // Expected items are pushed by write_expected(), popped by write_actual()
  // ---------------------------------------------------------------------------
  protected apb_seq_item exp_q [$];

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE — create the two analysis ports
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    exp_port = new("exp_port", this);
    act_port = new("act_port", this);
  endfunction

  // ---------------------------------------------------------------------------
  // WRITE_EXPECTED — called when sys_monitor broadcasts an expected transaction
  //
  // Actions:
  //   1. Push the item onto the expected queue (FIFO)
  //   2. If it's a write transaction, update ref_mem with the write data
  //      This ensures the scoreboard knows what data SHOULD be at each address
  // ---------------------------------------------------------------------------
  virtual function void write_expected(apb_seq_item item);
    exp_q.push_back(item);
    if (!item.read) begin
      ref_mem[item.addr] = item.wdata;    // Store: "address X should contain data D"
      `uvm_info("SCB_EXP", $sformatf("Ref Memory Updated: Addr=0x%03h, Data=0x%02h", item.addr, item.wdata), UVM_HIGH)
    end
  endfunction

  // ---------------------------------------------------------------------------
  // WRITE_ACTUAL — called when bus_monitor broadcasts an actual bus transaction
  //
  // This is the main checking function. For each actual transaction:
  //   1. Pop the corresponding expected transaction from the FIFO queue
  //   2. Run all verification checks (direction, address, data, select, error)
  //   3. Increment pass/error counters for each check
  //
  // If the expected queue is empty, it means we received a bus transaction
  // that was not initiated by the system — this is flagged as an error.
  // ---------------------------------------------------------------------------
  virtual function void write_actual(apb_seq_item item);
    apb_seq_item exp_item;
    bit [7:0] expected_rdata;
    bit       expected_psel1;
    bit       expected_psel2;

    // --- Guard: expected queue must not be empty ---
    if (exp_q.size() == 0) begin
      num_errors++;
      `uvm_error("SCB_ACT", "Received actual APB transaction but expected queue is empty!")
      return;
    end

    // Pop the oldest expected item (FIFO order)
    exp_item = exp_q.pop_front();

    // -----------------------------------------------------------------------
    // CHECK 1: DIRECTION
    // System 'read' flag should be the inverse of bus 'pwrite' signal.
    // read=0 (write request) → pwrite should be 1
    // read=1 (read request)  → pwrite should be 0
    // -----------------------------------------------------------------------
    if (item.pwrite !== ~exp_item.read) begin
      num_errors++;
      `uvm_error("SCB", $sformatf("DIRECTION MISMATCH: System read=%0b, APB pwrite=%0b", exp_item.read, item.pwrite))
    end
    else begin
      num_passes++;
    end

    // -----------------------------------------------------------------------
    // CHECK 2: ADDRESS
    // The address on the APB bus must match what the system requested.
    // -----------------------------------------------------------------------
    if (item.paddr !== exp_item.addr) begin
      num_errors++;
      `uvm_error("SCB", $sformatf("ADDRESS MISMATCH: System addr=0x%03h, APB paddr=0x%03h", exp_item.addr, item.paddr))
    end
    else begin
      num_passes++;
    end

    // -----------------------------------------------------------------------
    // CHECK 3: WRITE DATA (only for write transactions)
    // The write data on the APB bus must match what the system provided.
    // -----------------------------------------------------------------------
    if (item.pwrite) begin
      num_writes++;
      if (item.pwdata !== exp_item.wdata) begin
        num_errors++;
        `uvm_error("SCB", $sformatf("WRITE DATA MISMATCH: System wdata=0x%02h, APB pwdata=0x%02h", exp_item.wdata, item.pwdata))
      end
      else begin
        num_passes++;
      end
    end

    // -----------------------------------------------------------------------
    // CHECK 4: SLAVE SELECT ROUTING
    // Address bit[8] determines which slave is selected:
    //   addr[8]=0 → PSEL1=1, PSEL2=0 (Slave 1 selected)
    //   addr[8]=1 → PSEL1=0, PSEL2=1 (Slave 2 selected)
    // -----------------------------------------------------------------------
    expected_psel1 = ~item.paddr[8];    // Slave 1 selected when addr[8]=0
    expected_psel2 =  item.paddr[8];    // Slave 2 selected when addr[8]=1
    if (item.psel1 !== expected_psel1 || item.psel2 !== expected_psel2) begin
      num_errors++;
      `uvm_error("SCB", $sformatf("SLAVE SELECT MISMATCH: Addr=0x%03h -> expected PSEL1=%0b PSEL2=%0b, got PSEL1=%0b PSEL2=%0b", item.paddr, expected_psel1, expected_psel2, item.psel1, item.psel2))
    end
    else begin
      num_passes++;
    end

    // -----------------------------------------------------------------------
    // CHECK 5 & 6: READ DATA (only for read transactions)
    // Two sub-checks:
    //   5a. Bus read data vs. reference memory (or fallback pattern)
    //   5b. System-side read data vs. bus read data (end-to-end check)
    // -----------------------------------------------------------------------
    if (!item.pwrite) begin
      num_reads++;

      // Determine expected read data:
      //   - If address was previously written: expect that stored data
      //   - If address was never written: expect fallback pattern (addr[7:0] ^ 0xA5)
      if (ref_mem.exists(item.paddr)) begin
        expected_rdata = ref_mem[item.paddr];
      end
      else begin
        expected_rdata = item.paddr[7:0] ^ 8'hA5;    // Fallback: matches slave driver logic
      end

      // CHECK 5: Compare actual bus read data against expected
      if (item.rdata !== expected_rdata) begin
        num_errors++;
        `uvm_error("SCB", $sformatf("READ DATA MISMATCH ON BUS: Addr=0x%03h expected_rdata=0x%02h got_rdata=0x%02h", item.paddr, expected_rdata, item.rdata))
      end
      else begin
        num_passes++;
      end

      // CHECK 6: Compare system-side read data against bus-side read data
      // This verifies the DUT correctly propagated PRDATA to apb_read_data_out
      if (exp_item.rdata !== item.rdata) begin
        num_errors++;
        `uvm_error("SCB", $sformatf("SYSTEM READ DATA MISMATCH: expected_system_rdata=0x%02h actual_bus_rdata=0x%02h", exp_item.rdata, item.rdata))
      end
      else begin
        num_passes++;
      end
    end

    // -----------------------------------------------------------------------
    // CHECK 7: PENABLE must be high during a completed handshake
    // By definition, a completed transfer has PENABLE=1 (ACCESS phase)
    // -----------------------------------------------------------------------
    if (item.penable !== 1'b1) begin
      num_errors++;
      `uvm_error("SCB", "PENABLE was low during completed handshake transfer!")
    end
    else begin
      num_passes++;
    end

    // -----------------------------------------------------------------------
    // CHECK 8: PSLVERR must be low for normal (error-free) operation
    // If the DUT incorrectly asserts PSLVERR, we catch it here
    // -----------------------------------------------------------------------
    if (item.pslverr !== 1'b0) begin
      num_errors++;
      `uvm_error("SCB", $sformatf("PSLVERR was active on transfer to address 0x%03h!", item.paddr))
    end
    else begin
      num_passes++;
    end

  endfunction

  // ---------------------------------------------------------------------------
  // REPORT PHASE — print final verification summary at end of simulation
  //
  // This runs after all transactions are complete and displays:
  //   - Number of write/read transactions verified
  //   - Total individual assertion pass/fail counts
  //   - Overall PASS/FAIL verdict
  // ---------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", "================================================", UVM_LOW)
    `uvm_info("SCB", "       APB MASTER SCOREBOARD SUMMARY", UVM_LOW)
    `uvm_info("SCB", "================================================", UVM_LOW)
    `uvm_info("SCB", $sformatf("  Write Transactions Verified: %0d", num_writes), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Read Transactions Verified : %0d", num_reads), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Assertions Passed    : %0d", num_passes), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Assertions Failed    : %0d", num_errors), UVM_LOW)
    `uvm_info("SCB", "================================================", UVM_LOW)
    if (num_errors == 0)
      `uvm_info("SCB", "  RESULT: ALL CHECKS PASSED SUCCESSFULLY!", UVM_LOW)
    else
      `uvm_error("SCB", $sformatf("  RESULT: %0d CHECKS FAILED!", num_errors))
  endfunction

endclass
