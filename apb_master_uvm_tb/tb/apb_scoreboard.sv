`include "uvm_macros.svh"
import uvm_pkg::*;

`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp_expected #(apb_seq_item, apb_scoreboard) exp_port;
  uvm_analysis_imp_actual   #(apb_seq_item, apb_scoreboard) act_port;

  apb_seq_item exp_queue[$];
  apb_seq_item act_queue[$];
  int pass_count, fail_count;

  function new(string name = "apb_scoreboard", uvm_component parent);
    super.new(name, parent);
    pass_count = 0; fail_count = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    exp_port = new("exp_port", this);
    act_port = new("act_port", this);
  endfunction

  // Queue expected, then try to match
  virtual function void write_expected(apb_seq_item item);
    apb_seq_item item_copy = apb_seq_item::type_id::create("exp_copy");
    item_copy.copy(item);
    exp_queue.push_back(item_copy);
    try_compare();
  endfunction

  // Queue actual, then try to match
  virtual function void write_actual(apb_seq_item item);
    apb_seq_item item_copy = apb_seq_item::type_id::create("act_copy");
    item_copy.copy(item);
    act_queue.push_back(item_copy);
    try_compare();
  endfunction

  // Compare when both queues have entries — order-independent
  function void try_compare();
    apb_seq_item exp, act;
    bit mismatch;
    string dir;

    while (exp_queue.size() > 0 && act_queue.size() > 0) begin
      exp = exp_queue.pop_front();
      act = act_queue.pop_front();
      mismatch = 0;
      dir = exp.read ? "READ" : "WRITE";

      // 1. Address
      if (exp.addr !== act.paddr) begin
        `uvm_error("SCB", $sformatf("[%s] ADDR MISMATCH: exp=0x%03h act=0x%03h", dir, exp.addr, act.paddr))
        mismatch = 1;
      end

      // 2. Direction: exp.read=0 means write, act.pwrite=1 means write
      if (exp.read !== ~act.pwrite) begin
        `uvm_error("SCB", $sformatf("[%s] DIR MISMATCH: exp.read=%0b act.pwrite=%0b", dir, exp.read, act.pwrite))
        mismatch = 1;
      end

      // 3. Write data (writes only)
      if (!exp.read && exp.wdata !== act.pwdata) begin
        `uvm_error("SCB", $sformatf("[WRITE] WDATA MISMATCH: exp=0x%02h act=0x%02h", exp.wdata, act.pwdata))
        mismatch = 1;
      end

      // 4. Read data (reads only)
      if (exp.read && exp.rdata !== act.rdata) begin
        `uvm_error("SCB", $sformatf("[READ] RDATA MISMATCH: exp=0x%02h act=0x%02h", exp.rdata, act.rdata))
        mismatch = 1;
      end

      // 5. PSEL routing: addr[8]=0 → PSEL1, addr[8]=1 → PSEL2
      if (!exp.addr[8] && !act.psel1) begin
        `uvm_error("SCB", $sformatf("[%s] PSEL1 expected high for addr=0x%03h, got %0b", dir, exp.addr, act.psel1))
        mismatch = 1;
      end
      if (exp.addr[8] && !act.psel2) begin
        `uvm_error("SCB", $sformatf("[%s] PSEL2 expected high for addr=0x%03h, got %0b", dir, exp.addr, act.psel2))
        mismatch = 1;
      end

      // 6. PENABLE must be 1 at handshake
      if (!act.penable) begin
        `uvm_error("SCB", $sformatf("[%s] PENABLE not asserted during ACCESS phase", dir))
        mismatch = 1;
      end

      // Verdict
      if (mismatch) begin
        fail_count++;
        `uvm_error("SCB", $sformatf("[%s] *** FAIL *** addr=0x%03h", dir, exp.addr))
      end else begin
        pass_count++;
        `uvm_info("SCB", $sformatf("[%s] *** PASS *** addr=0x%03h data=0x%02h psel1=%0b psel2=%0b",
                  dir, act.paddr, exp.read ? act.rdata : act.pwdata, act.psel1, act.psel2), UVM_LOW)
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", "========================================", UVM_LOW)
    `uvm_info("SCB", $sformatf("  SCOREBOARD FINAL SUMMARY"), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total : %0d", pass_count + fail_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  PASS  : %0d", pass_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  FAIL  : %0d", fail_count), UVM_LOW)
    `uvm_info("SCB", "========================================", UVM_LOW)

    if (exp_queue.size() > 0)
      `uvm_warning("SCB", $sformatf("%0d expected items unmatched", exp_queue.size()))
    if (act_queue.size() > 0)
      `uvm_warning("SCB", $sformatf("%0d actual items unmatched", act_queue.size()))

    if (fail_count > 0)
      `uvm_error("SCB", "TEST FAILED")
    else if (pass_count == 0)
      `uvm_warning("SCB", "No transactions compared — check monitors")
    else
      `uvm_info("SCB", "TEST PASSED", UVM_LOW)
  endfunction
endclass
