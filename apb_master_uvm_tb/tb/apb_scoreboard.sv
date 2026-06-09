`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class apb_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp_expected #(apb_seq_item, apb_scoreboard) exp_port; // Analysis implementation port for system requests
  uvm_analysis_imp_actual   #(apb_seq_item, apb_scoreboard) act_port;

  int num_writes     = 0;
  int num_reads      = 0;
  int num_passes     = 0;
  int num_errors     = 0;

  protected bit [7:0] ref_mem [bit [8:0]];
  protected apb_seq_item exp_q [$];

  function new(string name = "apb_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    exp_port = new("exp_port", this);
    act_port = new("act_port", this);
  endfunction

  virtual function void write_expected(apb_seq_item item);
    exp_q.push_back(item);
    if (!item.read) begin
      ref_mem[item.addr] = item.wdata;
      `uvm_info("SCB_EXP", $sformatf("Ref Memory Updated: Addr=0x%03h, Data=0x%02h", item.addr, item.wdata), UVM_HIGH)
    end
  endfunction

  virtual function void write_actual(apb_seq_item item);
    apb_seq_item exp_item;
    bit [7:0] expected_rdata;
    bit       expected_psel1;
    bit       expected_psel2;

    if (exp_q.size() == 0) begin
      num_errors++;
      `uvm_error("SCB_ACT", "Received actual APB transaction but expected queue is empty!")
      return;
    end

    exp_item = exp_q.pop_front();

    if (item.pwrite !== ~exp_item.read) begin            // Compares bus direction (1=write) against system command (1=read)
      num_errors++;
      `uvm_error("SCB", $sformatf("DIRECTION MISMATCH: System read=%0b, APB pwrite=%0b", exp_item.read, item.pwrite))
    end
    else begin
      num_passes++;
    end

    if (item.paddr !== exp_item.addr) begin
      num_errors++;
      `uvm_error("SCB", $sformatf("ADDRESS MISMATCH: System addr=0x%03h, APB paddr=0x%03h", exp_item.addr, item.paddr))
    end
    else begin
      num_passes++;
    end

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

    expected_psel1 = ~item.paddr[8];                     // Slave 1 selected when address bit 8 is low
    expected_psel2 =  item.paddr[8];                     // Slave 2 selected when address bit 8 is high
    if (item.psel1 !== expected_psel1 || item.psel2 !== expected_psel2) begin
      num_errors++;
      `uvm_error("SCB", $sformatf("SLAVE SELECT MISMATCH: Addr=0x%03h -> expected PSEL1=%0b PSEL2=%0b, got PSEL1=%0b PSEL2=%0b", item.paddr, expected_psel1, expected_psel2, item.psel1, item.psel2))
    end
    else begin
      num_passes++;
    end

    if (!item.pwrite) begin
      num_reads++;
      if (ref_mem.exists(item.paddr)) begin
        expected_rdata = ref_mem[item.paddr];            // Retrieves expected byte from reference memory
      end
      else begin                                         // Address never written before
        expected_rdata = item.paddr[7:0] ^ 8'hA5;        // Recomputes expected fallback pattern matching the slave
      end

      if (item.rdata !== expected_rdata) begin
        num_errors++;
        `uvm_error("SCB", $sformatf("READ DATA MISMATCH ON BUS: Addr=0x%03h expected_rdata=0x%02h got_rdata=0x%02h", item.paddr, expected_rdata, item.rdata))
      end
      else begin
        num_passes++;
      end

      if (exp_item.rdata !== item.rdata) begin
        num_errors++;
        `uvm_error("SCB", $sformatf("SYSTEM READ DATA MISMATCH: expected_system_rdata=0x%02h actual_bus_rdata=0x%02h", exp_item.rdata, item.rdata))
      end
      else begin
        num_passes++;
      end
    end

    if (item.penable !== 1'b1) begin
      num_errors++;
      `uvm_error("SCB", "PENABLE was low during completed handshake transfer!")
    end
    else begin
      num_passes++;
    end

    if (item.pslverr !== 1'b0) begin
      num_errors++;
      `uvm_error("SCB", $sformatf("PSLVERR was active on transfer to address 0x%03h!", item.paddr))
    end
    else begin
      num_passes++;
    end

  endfunction

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
    else                                                 // If verification failures occurred
      `uvm_error("SCB", $sformatf("  RESULT: %0d CHECKS FAILED!", num_errors))
  endfunction

endclass
