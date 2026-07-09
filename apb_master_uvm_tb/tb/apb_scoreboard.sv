

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

`uvm_analysis_imp_decl(_req)
`uvm_analysis_imp_decl(_comp)

  // Two analysis exports: one for requests, one for completions
  uvm_analysis_imp_req  #(apb_seq_item, apb_scoreboard) req_imp;
  uvm_analysis_imp_comp #(apb_seq_item, apb_scoreboard) comp_imp;

  // Queue of outstanding requests (what the master asked for)
  apb_seq_item req_q[$];

  // Golden memory: what SHOULD be at each address, based on writes we've seen
  bit [7:0] shadow_mem [bit [8:0]];

  // Result counters
  int unsigned num_req;
  int unsigned num_comp;
  int unsigned num_pass;
  int unsigned num_ghost;       // completion with no matching request
  int unsigned num_route_err;   // write data/addr didn't match request
  int unsigned num_loop_err;    // read data didn't match memory

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    req_imp  = new("req_imp",  this);
    comp_imp = new("comp_imp", this);
  endfunction

  // ---------- Called when the INPUT monitor sees a request (SETUP) ----------
  function void write_req(apb_seq_item tr);
    apb_seq_item cloned;
    $cast(cloned, tr.clone());   // store a copy so later changes don't affect it
    req_q.push_back(cloned);
    num_req++;
    `uvm_info("SB", $sformatf("REQUEST  logged: %s addr=0x%0h wdata=0x%0h",
              tr.read ? "READ" : "WRITE", tr.addr, tr.wdata), UVM_MEDIUM)
  endfunction

  // ---------- Called when the OUTPUT monitor sees a completion ----------
  function void write_comp(apb_seq_item tr);
    apb_seq_item req;
    num_comp++;

    // --- CHECKER 1: GHOST detection ---
    // A completion arrived but no request is waiting for it.
    if (req_q.size() == 0) begin
      num_ghost++;
      `uvm_error("SB_GHOST",
        $sformatf("GHOST completion on bus (PADDR=0x%0h PWDATA=0x%0h) with NO matching request. DUT produced a transaction the master never asked for.",
                  tr.paddr, tr.pwdata))
      return;
    end

    // Pop the oldest outstanding request to match against this completion
    req = req_q.pop_front();

    if (req.read == 1'b0) begin
      // ===== WRITE =====
      // --- CHECKER 2: write-data routing ---
      // The data/addr on the bus must match what the master requested.
      if (tr.paddr !== req.addr || tr.pwdata !== req.wdata) begin
        num_route_err++;
        `uvm_error("SB_ROUTE",
          $sformatf("WRITE routing mismatch. Master asked addr=0x%0h data=0x%0h, but bus carried PADDR=0x%0h PWDATA=0x%0h.",
                    req.addr, req.wdata, tr.paddr, tr.pwdata))
      end
      else begin
        shadow_mem[req.addr] = req.wdata;   // record the write in golden memory
        num_pass++;
        `uvm_info("SB", $sformatf("WRITE OK: addr=0x%0h data=0x%0h",
                  req.addr, req.wdata), UVM_MEDIUM)
      end
    end
    else begin
      // ===== READ =====
      // --- CHECKER 3: read loopback ---
      // Data read back must equal what we previously wrote (golden memory).
      bit [7:0] exp = shadow_mem.exists(req.addr) ? shadow_mem[req.addr] : 8'h00;
      if (tr.rdata !== exp) begin
        num_loop_err++;
        `uvm_error("SB_LOOPBACK",
          $sformatf("READ loopback mismatch. addr=0x%0h expected=0x%0h (from memory), bus PRDATA=0x%0h.",
                    req.addr, exp, tr.rdata))
      end
      else begin
        num_pass++;
        `uvm_info("SB", $sformatf("READ OK: addr=0x%0h data=0x%0h",
                  req.addr, exp), UVM_MEDIUM)
      end
    end
  endfunction

  // ---------- End of test: anything left un-matched was DROPPED ----------
  function void check_phase(uvm_phase phase);
    // --- CHECKER 1 (other half): DROP detection ---
    foreach (req_q[i]) begin
      `uvm_error("SB_DROP",
        $sformatf("DROPPED transaction: master requested %s addr=0x%0h data=0x%0h but NO completion ever appeared on the bus.",
                  req_q[i].read ? "READ" : "WRITE",
                  req_q[i].addr, req_q[i].wdata))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    int unsigned num_drop = req_q.size();
    string verdict = (num_ghost==0 && num_route_err==0 &&
                      num_loop_err==0 && num_drop==0) ? "PASS" : "FAIL";

    `uvm_info("SB_SUMMARY",
      $sformatf({"\n",
        "============== APB SCOREBOARD SUMMARY ==============\n",
        "  Requests seen      : %0d\n",
        "  Completions seen   : %0d\n",
        "  Passed             : %0d\n",
        "  Ghost completions  : %0d\n",
        "  Dropped requests   : %0d\n",
        "  Write routing errs : %0d\n",
        "  Read loopback errs : %0d\n",
        "  --------------------------------------------------\n",
        "  RESULT: %s\n",
        "==================================================="},
        num_req, num_comp, num_pass, num_ghost, num_drop,
        num_route_err, num_loop_err, verdict),
      UVM_NONE)
  endfunction

endclass