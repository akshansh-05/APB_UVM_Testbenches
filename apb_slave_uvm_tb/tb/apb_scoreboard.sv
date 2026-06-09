//     2. Maintains a REFERENCE MODEL (a simple memory array).
//   The scoreboard has its own associative array (ref_mem) that acts as
//   a "golden" copy of what the slave's memory SHOULD contain.
//   - On a WRITE: Store the data in ref_mem (no checking needed).

// The dual-port scoreboard compares expected system requests with actual APB
// bus transfers to verify correct address decoding, data compliance, and status lines.
class apb_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_seq_item, apb_scoreboard) analysis_export;

  // Declare reference memory (associative array where key is address and value is data)
  bit [7:0] ref_mem [int];

  int num_writes  = 0;
  int num_reads   = 0;
  int num_passes  = 0;
  int num_errors  = 0;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(apb_seq_item item);

    // Update the reference model on writes, and compare read data against reference memory on reads
    if (item.write) begin
      ref_mem[item.addr] = item.wdata;
      num_writes++;
      `uvm_info("SCB", $sformatf("WRITE: addr=0x%02h data=0x%02h (stored in ref model)",
                                  item.addr, item.wdata), UVM_MEDIUM)
    end

    else begin // Otherwise, it is a Read operation (item.write is 0)
      num_reads++;

      if (ref_mem.exists(item.addr)) begin
        if (item.rdata === ref_mem[item.addr]) begin
          num_passes++;
          `uvm_info("SCB", $sformatf("READ PASS: addr=0x%02h expected=0x%02h got=0x%02h",
                                      item.addr, ref_mem[item.addr], item.rdata), UVM_MEDIUM)
        end
        else begin // If they don't match, we found a bug!
          num_errors++;
          `uvm_error("SCB", $sformatf("READ FAIL: addr=0x%02h expected=0x%02h got=0x%02h",
                                       item.addr, ref_mem[item.addr], item.rdata))
        end
      end
      else begin // If address was never written, we cannot verify it
        // Just log it as information.
        `uvm_info("SCB", $sformatf("READ (no ref): addr=0x%02h got=0x%02h (location never written)",
                                    item.addr, item.rdata), UVM_MEDIUM)
      end
    end

  endfunction
 
    // Report Phase: display simulation run statistics, error summaries, and checks passed
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
    if (num_errors == 0) // If no errors occurred
      `uvm_info("SCB", "  RESULT: ALL CHECKS PASSED", UVM_LOW)
    else
      `uvm_error("SCB", $sformatf("  RESULT: %0d CHECKS FAILED", num_errors))
  endfunction

endclass
