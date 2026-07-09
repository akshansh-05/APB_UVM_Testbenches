`include "uvm_macros.svh"
import uvm_pkg::*;

`uvm_analysis_imp_decl(_req)
`uvm_analysis_imp_decl(_comp)

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp_req  #(apb_seq_item, apb_scoreboard) req_imp;
  uvm_analysis_imp_comp #(apb_seq_item, apb_scoreboard) comp_imp;

  apb_seq_item req_q[$];
  bit [7:0] shadow_mem [bit [8:0]];

  // ---- DATA INTEGRITY counters ----
  int unsigned data_pass;
  int unsigned route_err;     // write data/addr didn't reach bus correctly
  int unsigned loop_err;      // read returned wrong data

  // ---- PROTOCOL counters ----
  int unsigned ghost_err;     // completion with no matching request
  int unsigned drop_err;      // request with no completion (end of test)

  // ---- bookkeeping ----
  int unsigned num_req;
  int unsigned num_comp;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    req_imp  = new("req_imp",  this);
    comp_imp = new("comp_imp", this);
  endfunction

  // ---------- REQUEST (from input monitor, at SETUP) ----------
  function void write_req(apb_seq_item tr);
    apb_seq_item cloned;
    $cast(cloned, tr.clone());
    req_q.push_back(cloned);
    num_req++;
  endfunction

  // ---------- COMPLETION (from output monitor, at PENABLE&PREADY) ----------
  function void write_comp(apb_seq_item tr);
    apb_seq_item req;
    num_comp++;

    // ===== PROTOCOL CHECK: ghost =====
    if (req_q.size() == 0) begin
      ghost_err++;
      `uvm_error("SB_PROTOCOL",
        $sformatf("GHOST completion (PADDR=0x%0h) with no matching request. DUT produced an unrequested transaction.",
                  tr.paddr))
      return;
    end

    req = req_q.pop_front();

    if (req.read == 1'b0) begin
      // ===== WRITE: data integrity =====
      if (tr.paddr !== req.addr || tr.pwdata !== req.wdata) begin
        route_err++;
        `uvm_error("SB_DATA",
          $sformatf("WRITE routing mismatch. Requested addr=0x%0h data=0x%0h, bus PADDR=0x%0h PWDATA=0x%0h.",
                    req.addr, req.wdata, tr.paddr, tr.pwdata))
      end
      else begin
        shadow_mem[req.addr] = req.wdata;
        data_pass++;
      end
    end
    else begin
      // ===== READ: data integrity (loopback) =====
      bit [7:0] exp = shadow_mem.exists(req.addr) ? shadow_mem[req.addr] : 8'h00;
      if (tr.rdata !== exp) begin
        loop_err++;
        `uvm_error("SB_DATA",
          $sformatf("READ loopback mismatch. addr=0x%0h expected=0x%0h, bus PRDATA=0x%0h.",
                    req.addr, exp, tr.rdata))
      end
      else begin
        data_pass++;
      end
    end
  endfunction

  // ---------- End of test: leftover requests = dropped (protocol) ----------
  function void check_phase(uvm_phase phase);
    foreach (req_q[i]) begin
      drop_err++;
      `uvm_error("SB_PROTOCOL",
        $sformatf("DROPPED: request %s addr=0x%0h never completed on the bus.",
                  req_q[i].read ? "READ" : "WRITE", req_q[i].addr))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    // Two independent verdicts
    string data_verdict     = (route_err==0 && loop_err==0)  ? "PASS" : "FAIL";
    string protocol_verdict = (ghost_err==0 && drop_err==0)  ? "PASS" : "FAIL";

    `uvm_info("SB_SUMMARY",
      $sformatf({"\n",
        "================= APB SCOREBOARD =================\n",
        "  Requests   : %0d      Completions : %0d\n",
        "  -------------------------------------------------\n",
        "  DATA INTEGRITY\n",
        "     passed            : %0d\n",
        "     write routing err : %0d\n",
        "     read loopback err : %0d\n",
        "     >> DATA VERDICT   : %s\n",
        "  -------------------------------------------------\n",
        "  PROTOCOL COMPLIANCE\n",
        "     ghost completions : %0d\n",
        "     dropped requests  : %0d\n",
        "     >> PROTOCOL VERDICT: %s\n",
        "================================================="},
        num_req, num_comp,
        data_pass, route_err, loop_err, data_verdict,
        ghost_err, drop_err, protocol_verdict),
      UVM_NONE)
  endfunction

endclass