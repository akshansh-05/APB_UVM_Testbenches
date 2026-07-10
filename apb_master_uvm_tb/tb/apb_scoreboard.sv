`include "uvm_macros.svh"
import uvm_pkg::*;

`uvm_analysis_imp_decl(_exp)
`uvm_analysis_imp_decl(_act)

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp_exp #(apb_seq_item, apb_scoreboard) exp_imp;   // from sys_monitor
  uvm_analysis_imp_act #(apb_seq_item, apb_scoreboard) act_imp;   // from slv_monitor

  apb_seq_item exp_q[$];
  bit [7:0] shadow_mem [bit [8:0]];

  int unsigned data_pass;
  int unsigned route_err;
  int unsigned loop_err;
  int unsigned ghost_err;
  int unsigned drop_err;

  int unsigned num_exp;
  int unsigned num_act;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    exp_imp = new("exp_imp", this);
    act_imp = new("act_imp", this);
  endfunction

  // ---- EXPECTED (from system monitor) ----
  function void write_exp(apb_seq_item tr);
    apb_seq_item cloned;
    $cast(cloned, tr.clone());
    exp_q.push_back(cloned);
    num_exp++;
  endfunction

  // ---- ACTUAL (from slave monitor / bus) ----
  function void write_act(apb_seq_item tr);
    apb_seq_item exp;
    num_act++;

    // GHOST: bus completion with no outstanding expected
    if (exp_q.size() == 0) begin
      ghost_err++;
      `uvm_error("SB_GHOST",
        $sformatf("GHOST completion on bus (PADDR=0x%0h PWDATA=0x%0h) with no matching request.",
                  tr.paddr, tr.pwdata))
      return;
    end

    exp = exp_q.pop_front();

    if (exp.read == 1'b0) begin
      // WRITE translation: bus addr/data vs requested
      if (tr.paddr !== exp.addr || tr.pwdata !== exp.wdata) begin
        route_err++;
        `uvm_error("SB_ROUTE",
          $sformatf("WRITE translation mismatch. Requested addr=0x%0h data=0x%0h, bus PADDR=0x%0h PWDATA=0x%0h.",
                    exp.addr, exp.wdata, tr.paddr, tr.pwdata))
      end
      else begin
        shadow_mem[exp.addr] = exp.wdata;
        data_pass++;
        `uvm_info("SB", $sformatf("WRITE OK: addr=0x%0h data=0x%0h", exp.addr, exp.wdata), UVM_MEDIUM)
      end
    end
    else begin
      // READ loopback: bus read data vs golden memory
      bit [7:0] expected_rd = shadow_mem.exists(exp.addr) ? shadow_mem[exp.addr] : 8'h00;
      if (tr.rdata !== expected_rd) begin
        loop_err++;
        `uvm_error("SB_LOOPBACK",
          $sformatf("READ loopback mismatch. addr=0x%0h expected=0x%0h, bus PRDATA=0x%0h.",
                    exp.addr, expected_rd, tr.rdata))
      end
      else begin
        data_pass++;
        `uvm_info("SB", $sformatf("READ OK: addr=0x%0h data=0x%0h", exp.addr, expected_rd), UVM_MEDIUM)
      end
    end
  endfunction

  // ---- End of test: leftover expected = dropped ----
  function void check_phase(uvm_phase phase);
    foreach (exp_q[i]) begin
      drop_err++;
      `uvm_error("SB_DROP",
        $sformatf("DROPPED: requested %s addr=0x%0h data=0x%0h but no bus completion occurred.",
                  exp_q[i].read ? "READ" : "WRITE", exp_q[i].addr, exp_q[i].wdata))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    string verdict = (route_err==0 && loop_err==0 &&
                      ghost_err==0 && drop_err==0) ? "PASS" : "FAIL";

    `uvm_info("SB_SUMMARY",
      $sformatf({"\n",
        "============= APB DATA-INTEGRITY SCOREBOARD =============\n",
        "  Expected   : %0d      Actual (bus) : %0d\n",
        "  --------------------------------------------------------\n",
        "  passed              : %0d\n",
        "  write routing err   : %0d\n",
        "  read loopback err   : %0d\n",
        "  ghost completions   : %0d\n",
        "  dropped requests    : %0d\n",
        "  --------------------------------------------------------\n",
        "  DATA INTEGRITY VERDICT: %s\n",
        "========================================================"},
        num_exp, num_act, data_pass, route_err, loop_err,
        ghost_err, drop_err, verdict),
      UVM_NONE)
  endfunction

endclass