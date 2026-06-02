// ============================================================================
// FILE: apb_scoreboard.sv
// DESCRIPTION:
//   The Scoreboard is the "checker" of the testbench. It:
//     1. Receives observed transactions from the Monitor (via analysis port).
//     2. Maintains a REFERENCE MODEL (a simple memory array).
//     3. Compares DUT behavior against the reference model.
//     4. Reports PASS or FAIL.
//
//   REFERENCE MODEL:
//   ----------------
//   The scoreboard has its own associative array (ref_mem) that acts as
//   a "golden" copy of what the slave's memory SHOULD contain.
//
//   - On a WRITE: Store the data in ref_mem (no checking needed).
//   - On a READ:  Compare DUT's rdata with ref_mem. If they differ → BUG!
//
//   HOW THE ANALYSIS PORT CONNECTION WORKS:
//   ----------------------------------------
//   Monitor.ap  ──(broadcasts)──►  Scoreboard.write(item)
//   The `write` method below is called automatically whenever the
//   monitor broadcasts a transaction.
// ============================================================================

class apb_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(apb_scoreboard)

  // Analysis implementation port — receives items from the monitor
  uvm_analysis_imp #(apb_seq_item, apb_scoreboard) analysis_export;

  // ---- Reference Model: Golden memory ----
  // Associative array: ref_mem[address] = expected_data
  bit [7:0] ref_mem [int];

  // ---- Counters for summary ----
  int num_writes  = 0;
  int num_reads   = 0;
  int num_passes  = 0;
  int num_errors  = 0;

  // ---- Constructor ----
  function new(string name = "apb_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // ---- Write Method: Called automatically when monitor broadcasts ----
  // This is the heart of the scoreboard.
  function void write(apb_seq_item item);

    if (item.write) begin
      // ========== WRITE TRANSACTION ==========
      // Store the written data in our reference memory
      ref_mem[item.addr] = item.wdata;
      num_writes++;
      `uvm_info("SCB", $sformatf("WRITE: addr=0x%02h data=0x%02h (stored in ref model)",
                                  item.addr, item.wdata), UVM_MEDIUM)
    end

    else begin
      // ========== READ TRANSACTION ==========
      // Compare DUT's read data against our reference model
      num_reads++;

      if (ref_mem.exists(item.addr)) begin
        // We have a reference value — compare!
        if (item.rdata === ref_mem[item.addr]) begin
          num_passes++;
          `uvm_info("SCB", $sformatf("READ PASS: addr=0x%02h expected=0x%02h got=0x%02h",
                                      item.addr, ref_mem[item.addr], item.rdata), UVM_MEDIUM)
        end
        else begin
          num_errors++;
          `uvm_error("SCB", $sformatf("READ FAIL: addr=0x%02h expected=0x%02h got=0x%02h",
                                       item.addr, ref_mem[item.addr], item.rdata))
        end
      end
      else begin
        // Address was never written — we can't predict the value.
        // Just log it as information.
        `uvm_info("SCB", $sformatf("READ (no ref): addr=0x%02h got=0x%02h (location never written)",
                                    item.addr, item.rdata), UVM_MEDIUM)
      end
    end

  endfunction

  // ---- Report Phase: Print final summary ----
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", "========================================", UVM_LOW)
    `uvm_info("SCB", "       SCOREBOARD SUMMARY", UVM_LOW)
    `uvm_info("SCB", "========================================", UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Writes : %0d", num_writes), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Reads  : %0d", num_reads), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Read Passes  : %0d", num_passes), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Read Errors  : %0d", num_errors), UVM_LOW)
    `uvm_info("SCB", "========================================", UVM_LOW)
    if (num_errors == 0)
      `uvm_info("SCB", "  RESULT: ALL CHECKS PASSED", UVM_LOW)
    else
      `uvm_error("SCB", $sformatf("  RESULT: %0d CHECKS FAILED", num_errors))
  endfunction

endclass
