//==============================================================================
// apb_scoreboard — APB DATA-INTEGRITY SCOREBOARD
//==============================================================================
// SCOPE: data integrity ONLY — i.e. did the transaction the master requested get
//        faithfully TRANSLATED onto the APB bus (system-side -> bus-side)?
//        Protocol/FSM compliance (legal state sequence, PENABLE timing, etc.) is
//        a SEPARATE checker axis and is intentionally out of scope here.
//
// TWO INDEPENDENT STREAMS (the key architectural property):
//   EXPECTED  <- sys_monitor : the request,  sampled at SETUP-entry
//   ACTUAL    <- slv_monitor : the bus txn,  sampled at completion (PENABLE&&PREADY)
//   Because they are sampled on INDEPENDENT events, we can detect a request that
//   never completed (DROP) and a completion with no request (GHOST). If both
//   streams keyed off the same event they would trivially agree and neither
//   could be detected.
//
// PAIRING: in-order FIFO (exp_q). Valid because APB is strictly ordered.
//
// FIVE CHECKERS:
//   1. GHOST   - bus completion with no outstanding request
//   2. WRITE   - bus PADDR/PWDATA == requested addr/data
//   3. R-ADDR  - bus PADDR == requested addr (read routed correctly)
//   4. R-DATA  - bus PRDATA == golden model value (read loopback)
//   5. DROP    - request left unmatched at end of test
//==============================================================================

`uvm_analysis_imp_decl(_exp)
`uvm_analysis_imp_decl(_act)

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp_exp #(apb_seq_item, apb_scoreboard) exp_imp;   // from sys_monitor
  uvm_analysis_imp_act #(apb_seq_item, apb_scoreboard) act_imp;   // from slv_monitor

  // Outstanding requests, awaiting their bus completion (in order).
  apb_seq_item exp_q[$];

  // Golden reference model of slave memory. Indexed by the 9-bit APB address.
  // Mirrors what the BUS actually wrote, so read-back can be checked.
  bit [7:0] shadow_mem [bit [8:0]];

  // Checker result counters
  int unsigned data_pass;
  int unsigned route_err;
  int unsigned loop_err;
  int unsigned ghost_err;
  int unsigned drop_err;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    exp_imp = new("exp_imp", this);
    act_imp = new("act_imp", this);
  endfunction

  //--------------------------------------------------------------------------
  // EXPECTED stream: the master's request (sampled at SETUP-entry).
  // Clone before storing — the monitor may reuse the handle.
  //--------------------------------------------------------------------------
  function void write_exp(apb_seq_item tr);
    apb_seq_item cloned;
    $cast(cloned, tr.clone());
    exp_q.push_back(cloned);
  endfunction

  //--------------------------------------------------------------------------
  // ACTUAL stream: what the DUT drove on the APB bus (sampled at completion).
  //--------------------------------------------------------------------------
  function void write_act(apb_seq_item act);
    apb_seq_item exp;
    bit [7:0]    golden_rd;
    bit          txn_ok;      // stays 1 only if every check for THIS txn passes

    // ---- CHECKER 1: GHOST ----
    if (exp_q.size() == 0) begin
      ghost_err++;
      `uvm_error("SB_GHOST",
        $sformatf("GHOST: bus completion PADDR=0x%0h with no matching request.",
                  act.paddr))
      return;
    end

    exp    = exp_q.pop_front();
    txn_ok = 1'b1;   // assume good; any failed check clears it

    if (exp.read == 1'b0) begin
      //----------------------------------------------------------------------
      // WRITE
      //----------------------------------------------------------------------
      // Update the golden model from the ACTUAL bus values (right or wrong),
      // so later reads are checked against what really got stored.
      shadow_mem[act.paddr] = act.pwdata;

      // ---- CHECKER 2: WRITE ROUTING ----
      if (act.paddr !== exp.addr || act.pwdata !== exp.wdata) begin
        route_err++;
        txn_ok = 1'b0;
        `uvm_error("SB_ROUTE",
          $sformatf("WRITE mismatch. Req addr=0x%0h data=0x%0h | Bus PADDR=0x%0h PWDATA=0x%0h.",
                    exp.addr, exp.wdata, act.paddr, act.pwdata))
      end
    end
    else begin
      //----------------------------------------------------------------------
      // READ
      //----------------------------------------------------------------------
      // ---- CHECKER 3: READ ADDRESS ROUTING ----
      if (act.paddr !== exp.addr) begin
        route_err++;
        txn_ok = 1'b0;
        `uvm_error("SB_ROUTE",
          $sformatf("READ addr mismatch. Req addr=0x%0h | Bus PADDR=0x%0h.",
                    exp.addr, act.paddr))
      end

      // ---- CHECKER 4: READ DATA LOOPBACK ----
      golden_rd = shadow_mem.exists(act.paddr) ? shadow_mem[act.paddr] : 8'h00;
      if (act.rdata !== golden_rd) begin
        loop_err++;
        txn_ok = 1'b0;
        `uvm_error("SB_LOOPBACK",
          $sformatf("READ loopback mismatch @ PADDR=0x%0h. Exp=0x%0h Act=0x%0h.",
                    act.paddr, golden_rd, act.rdata))
      end
    end

    // ---- Single, consistent PASS rule for every transaction ----
    if (txn_ok) data_pass++;
  endfunction

  //--------------------------------------------------------------------------
  // CHECKER 5: DROP — any request never matched by a completion.
  //--------------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    foreach (exp_q[i]) begin
      drop_err++;
      `uvm_error("SB_DROP",
        $sformatf("DROPPED: request %s addr=0x%0h never completed on the bus.",
                  exp_q[i].read ? "READ" : "WRITE", exp_q[i].addr))
    end
  endfunction

  //--------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    string verdict = (route_err==0 && loop_err==0 &&
                      ghost_err==0 && drop_err==0) ? "PASS" : "FAIL";

    `uvm_info("SB_SUMMARY",
      $sformatf({"\n",
        "============= APB DATA-INTEGRITY SCOREBOARD =============\n",
        "  passed              : %0d\n",
        "  write routing err   : %0d\n",
        "  read loopback err   : %0d\n",
        "  ghost completions   : %0d\n",
        "  dropped requests    : %0d\n",
        "  --------------------------------------------------------\n",
        "  DATA INTEGRITY VERDICT: %s\n",
        "========================================================"},
        data_pass, route_err, loop_err, ghost_err, drop_err, verdict),
      UVM_NONE)
  endfunction

endclass