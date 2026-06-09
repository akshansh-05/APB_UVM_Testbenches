// ============================================================================
// FILE: apb_scoreboard.sv
// DESCRIPTION: Dual-port checker scoreboard with self-contained reference memory
// ============================================================================

`uvm_analysis_imp_decl(_expected)                         // Declares suffix _expected for TLM analysis port
`uvm_analysis_imp_decl(_actual)                           // Declares suffix _actual for TLM analysis port

class apb_scoreboard extends uvm_scoreboard;             // Extends the standard UVM scoreboard base class

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(apb_scoreboard)                   // Registers the scoreboard class with factory

  // ---- TLM ANALYSIS IMP PORTS ----
  uvm_analysis_imp_expected #(apb_seq_item, apb_scoreboard) exp_port; // Analysis implementation port for system requests
  uvm_analysis_imp_actual   #(apb_seq_item, apb_scoreboard) act_port; // Analysis implementation port for APB bus transactions

  // ---- SCORING COUNTERS ----
  int num_writes     = 0;                                // Tracks total write transfers verified
  int num_reads      = 0;                                // Tracks total read transfers verified
  int num_passes     = 0;                                // Tracks total assertions that passed
  int num_errors     = 0;                                // Tracks total assertions that failed

  // ---- REFERENCE MEMORY & QUEUE ----
  protected bit [7:0] ref_mem [bit [8:0]];               // Scoreboard's internal reference memory block
  protected apb_seq_item exp_q [$];                      // FIFO queue storing system-side expected transactions

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_scoreboard", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls parent base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM BUILD PHASE ----
  function void build_phase(uvm_phase phase);            // Build phase callback
    super.build_phase(phase);                            // Calls parent build phase
    exp_port = new("exp_port", this);                    // Instantiates the expected analysis port object
    act_port = new("act_port", this);                    // Instantiates the actual analysis port object
  endfunction                                            // End of build phase declaration

  // ---- WRITE EXPECTED CALLBACK ----
  virtual function void write_expected(apb_seq_item item); // Callback triggered when system-side monitor broadcasts
    exp_q.push_back(item);                               // Pushes the expected request onto FIFO queue
    if (!item.read) begin                                // Checks if transaction is a system write request
      ref_mem[item.addr] = item.wdata;                   // Updates reference memory with the expected write data
      `uvm_info("SCB_EXP", $sformatf("Ref Memory Updated: Addr=0x%03h, Data=0x%02h", item.addr, item.wdata), UVM_HIGH) // Prints update info to log
    end                                                  // End of write command check block
  endfunction                                            // End of write_expected function declaration

  // ---- WRITE ACTUAL CALLBACK ----
  virtual function void write_actual(apb_seq_item item);  // Callback triggered when APB monitor broadcasts
    apb_seq_item exp_item;                               // Variable to hold popped expected transaction
    bit [7:0] expected_rdata;                            // Variable to calculate expected read data
    bit       expected_psel1;                            // Expected Slave 1 select signal
    bit       expected_psel2;                            // Expected Slave 2 select signal

    if (exp_q.size() == 0) begin                         // Checks for empty expected transaction queue
      num_errors++;                                      // Increments error count
      `uvm_error("SCB_ACT", "Received actual APB transaction but expected queue is empty!") // Prints error to console
      return;                                            // Exits function early
    end                                                  // End of empty queue check block

    exp_item = exp_q.pop_front();                        // Pops the oldest expected request from FIFO queue

    // ───────────────────────────────────────────────────────────
    // CHECK 1: Read/Write Direction matching
    // ───────────────────────────────────────────────────────────
    if (item.pwrite !== ~exp_item.read) begin            // Compares bus direction (1=write) against system command (1=read)
      num_errors++;                                      // Increments error count
      `uvm_error("SCB", $sformatf("DIRECTION MISMATCH: System read=%0b, APB pwrite=%0b", exp_item.read, item.pwrite)) // Reports direction error
    end                                                  // End of direction check block
    else begin                                           // Direction check passed
      num_passes++;                                      // Increments pass count
    end                                                  // End of direction check branch

    // ───────────────────────────────────────────────────────────
    // CHECK 2: Address Matching
    // ───────────────────────────────────────────────────────────
    if (item.paddr !== exp_item.addr) begin              // Compares bus address with expected system address
      num_errors++;                                      // Increments error count
      `uvm_error("SCB", $sformatf("ADDRESS MISMATCH: System addr=0x%03h, APB paddr=0x%03h", exp_item.addr, item.paddr)) // Reports address mismatch error
    end                                                  // End of address check block
    else begin                                           // Address check passed
      num_passes++;                                      // Increments pass count
    end                                                  // End of address check branch

    // ───────────────────────────────────────────────────────────
    // CHECK 3: Write Data Matching (Only for Writes)
    // ───────────────────────────────────────────────────────────
    if (item.pwrite) begin                               // Checks if transaction is a write command
      num_writes++;                                      // Increments total writes counter
      if (item.pwdata !== exp_item.wdata) begin          // Compares bus write data against expected system write data
        num_errors++;                                    // Increments error count
        `uvm_error("SCB", $sformatf("WRITE DATA MISMATCH: System wdata=0x%02h, APB pwdata=0x%02h", exp_item.wdata, item.pwdata)) // Reports write data mismatch error
      end                                                // End of write data check block
      else begin                                         // Write data check passed
        num_passes++;                                    // Increments pass count
      end                                                // End of write data check branch
    end                                                  // End of write command check block

    // ───────────────────────────────────────────────────────────
    // CHECK 4: Slave Select Routing
    // ───────────────────────────────────────────────────────────
    expected_psel1 = ~item.paddr[8];                     // Slave 1 selected when address bit 8 is low
    expected_psel2 =  item.paddr[8];                     // Slave 2 selected when address bit 8 is high
    if (item.psel1 !== expected_psel1 || item.psel2 !== expected_psel2) begin // Compares actual selects against expectations
      num_errors++;                                      // Increments error count
      `uvm_error("SCB", $sformatf("SLAVE SELECT MISMATCH: Addr=0x%03h -> expected PSEL1=%0b PSEL2=%0b, got PSEL1=%0b PSEL2=%0b", item.paddr, expected_psel1, expected_psel2, item.psel1, item.psel2)) // Reports select mismatch error
    end                                                  // End of select check block
    else begin                                           // Select check passed
      num_passes++;                                      // Increments pass count
    end                                                  // End of select check branch

    // ───────────────────────────────────────────────────────────
    // CHECK 5: Read Data Coherence (Only for Reads)
    // ───────────────────────────────────────────────────────────
    if (!item.pwrite) begin                              // Checks if transaction is a read command
      num_reads++;                                       // Increments total reads counter
      if (ref_mem.exists(item.paddr)) begin              // Checks if target read address was written previously in reference memory
        expected_rdata = ref_mem[item.paddr];            // Retrieves expected byte from reference memory
      end                                                // End of memory lookup block
      else begin                                         // Address never written before
        expected_rdata = item.paddr[7:0] ^ 8'hA5;        // Recomputes expected fallback pattern matching the slave
      end                                                // End of fallback computation block

      if (item.rdata !== expected_rdata) begin           // Compares actual read data on the APB bus against calculated expected data
        num_errors++;                                    // Increments error count
        `uvm_error("SCB", $sformatf("READ DATA MISMATCH ON BUS: Addr=0x%03h expected_rdata=0x%02h got_rdata=0x%02h", item.paddr, expected_rdata, item.rdata)) // Reports read mismatch error on APB bus
      end                                                // End read data check block
      else begin                                         // Read check passed
        num_passes++;                                    // Increments pass count
      end                                                // End read check branch

      if (exp_item.rdata !== item.rdata) begin           // Compares system read data output against actual bus read data
        num_errors++;                                    // Increments error count
        `uvm_error("SCB", $sformatf("SYSTEM READ DATA MISMATCH: expected_system_rdata=0x%02h actual_bus_rdata=0x%02h", exp_item.rdata, item.rdata)) // Reports system-side forwarding failure
      end                                                // End system read check block
      else begin                                         // System read check passed
        num_passes++;                                    // Increments pass count
      end                                                // End system read check branch
    end                                                  // End of read command check block

    // ───────────────────────────────────────────────────────────
    // CHECK 6: Control Signal Sanity Checks
    // ───────────────────────────────────────────────────────────
    if (item.penable !== 1'b1) begin                     // Checks that enable strobe was active during capture
      num_errors++;                                      // Increments error count
      `uvm_error("SCB", "PENABLE was low during completed handshake transfer!") // Reports enable error
    end                                                  // End enable check block
    else begin                                           // Enable check passed
      num_passes++;                                      // Increments pass count
    end                                                  // End enable check branch

    if (item.pslverr !== 1'b0) begin                     // Checks that error flag was deasserted for valid transfers
      num_errors++;                                      // Increments error count
      `uvm_error("SCB", $sformatf("PSLVERR was active on transfer to address 0x%03h!", item.paddr)) // Reports error status active
    end                                                  // End error flag check block
    else begin                                           // Error flag check passed
      num_passes++;                                      // Increments pass count
    end                                                  // End error flag check branch

  endfunction                                            // End of write_actual function declaration

  // ---- UVM REPORT PHASE ----
  function void report_phase(uvm_phase phase);            // Report phase callback
    super.report_phase(phase);                            // Calls parent report phase
    `uvm_info("SCB", "================================================", UVM_LOW) // Prints summary banner
    `uvm_info("SCB", "       APB MASTER SCOREBOARD SUMMARY", UVM_LOW)           // Prints summary title
    `uvm_info("SCB", "================================================", UVM_LOW) // Prints summary divider
    `uvm_info("SCB", $sformatf("  Write Transactions Verified: %0d", num_writes), UVM_LOW) // Logs verified writes
    `uvm_info("SCB", $sformatf("  Read Transactions Verified : %0d", num_reads), UVM_LOW)  // Logs verified reads
    `uvm_info("SCB", $sformatf("  Total Assertions Passed    : %0d", num_passes), UVM_LOW) // Logs passed assertions
    `uvm_info("SCB", $sformatf("  Total Assertions Failed    : %0d", num_errors), UVM_LOW) // Logs failed assertions
    `uvm_info("SCB", "================================================", UVM_LOW) // Prints summary footer
    if (num_errors == 0)                                 // Checks if no verification failures occurred
      `uvm_info("SCB", "  RESULT: ALL CHECKS PASSED SUCCESSFULLY!", UVM_LOW)     // Logs success status
    else                                                 // If verification failures occurred
      `uvm_error("SCB", $sformatf("  RESULT: %0d CHECKS FAILED!", num_errors))   // Logs failure count
  endfunction                                            // End of report phase declaration

endclass // End of apb_scoreboard class declaration
