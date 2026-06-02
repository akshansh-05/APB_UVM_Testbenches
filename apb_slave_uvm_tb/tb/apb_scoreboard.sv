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

class apb_scoreboard extends uvm_scoreboard; // Declare our scoreboard class extending uvm_scoreboard

  `uvm_component_utils(apb_scoreboard) // Register the scoreboard class with the UVM factory for dynamic construction

  // Declare the analysis implementation port to receive items from the monitor
  uvm_analysis_imp #(apb_seq_item, apb_scoreboard) analysis_export;

  // ---- Reference Model: Golden memory ----
  // Declare reference memory (associative array where key is address and value is data)
  bit [7:0] ref_mem [int];

  // ---- Counters for summary ----
  // Declare and initialize counters to track simulation statistics
  int num_writes  = 0; // Tracks total write operations received
  int num_reads   = 0; // Tracks total read operations received
  int num_passes  = 0; // Tracks successful read data checks (expected matches got)
  int num_errors  = 0; // Tracks read mismatches (failures)

  // ---- Constructor ----
  // Standard constructor required by UVM components
  function new(string name = "apb_scoreboard", uvm_component parent);
    super.new(name, parent); // Call parent class (uvm_scoreboard) constructor
  endfunction // End of constructor

  // ---- Build Phase ----
  // Build phase: Allocate components and set up connections
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); // Always call super.build_phase first to build parent class components
    analysis_export = new("analysis_export", this); // Instantiate the analysis port with its name and parent handle
  endfunction // End of build phase

  // ---- Write Method: Called automatically when monitor broadcasts ----
  // Write function: Called automatically whenever monitor sends an item via analysis port
  function void write(apb_seq_item item);

    if (item.write) begin // Check if the transaction is a Write operation (item.write is 1)
      // ========== WRITE TRANSACTION ==========
      ref_mem[item.addr] = item.wdata; // Update our reference model with the written data at the given address
      num_writes++; // Increment our write transaction counter
      `uvm_info("SCB", $sformatf("WRITE: addr=0x%02h data=0x%02h (stored in ref model)",
                                  item.addr, item.wdata), UVM_MEDIUM) // Print info log
    end // End of write block

    else begin // Otherwise, it is a Read operation (item.write is 0)
      // ========== READ TRANSACTION ==========
      num_reads++; // Increment our read transaction counter

      if (ref_mem.exists(item.addr)) begin // Check if this address was previously written to in our reference memory
        // We have a reference value — compare!
        if (item.rdata === ref_mem[item.addr]) begin // Check if actual read data matches expected
          num_passes++; // Increment the pass counter
          `uvm_info("SCB", $sformatf("READ PASS: addr=0x%02h expected=0x%02h got=0x%02h",
                                      item.addr, ref_mem[item.addr], item.rdata), UVM_MEDIUM) // Print success log
        end // End of pass block
        else begin // If they don't match, we found a bug!
          num_errors++; // Increment the failure/error counter
          `uvm_error("SCB", $sformatf("READ FAIL: addr=0x%02h expected=0x%02h got=0x%02h",
                                       item.addr, ref_mem[item.addr], item.rdata)) // Report UVM error (red in log)
        end // End of fail block
      end // End of exists check
      else begin // If address was never written, we cannot verify it
        // Just log it as information.
        `uvm_info("SCB", $sformatf("READ (no ref): addr=0x%02h got=0x%02h (location never written)",
                                    item.addr, item.rdata), UVM_MEDIUM) // Print info log
      end // End of else block
    end // End of write/read check

  endfunction // End of write function
 
  // ---- Report Phase: Print final summary ----
  // Report phase: Print final summary statistics after simulation finishes
  function void report_phase(uvm_phase phase);
    super.report_phase(phase); // Call parent class report phase
    `uvm_info("SCB", "========================================", UVM_LOW) // Print separator
    `uvm_info("SCB", "       SCOREBOARD SUMMARY", UVM_LOW) // Print title header
    `uvm_info("SCB", "========================================", UVM_LOW) // Print separator
    `uvm_info("SCB", $sformatf("  Total Writes : %0d", num_writes), UVM_LOW) // Report write count
    `uvm_info("SCB", $sformatf("  Total Reads  : %0d", num_reads), UVM_LOW) // Report read count
    `uvm_info("SCB", $sformatf("  Read Passes  : %0d", num_passes), UVM_LOW) // Report read pass count
    `uvm_info("SCB", $sformatf("  Read Errors  : %0d", num_errors), UVM_LOW) // Report read error count
    `uvm_info("SCB", "========================================", UVM_LOW) // Print separator
    if (num_errors == 0) // If no errors occurred
      `uvm_info("SCB", "  RESULT: ALL CHECKS PASSED", UVM_LOW) // Report final success status
    else // If errors occurred
      `uvm_error("SCB", $sformatf("  RESULT: %0d CHECKS FAILED", num_errors)) // Report final failure status
  endfunction // End of report phase

endclass
