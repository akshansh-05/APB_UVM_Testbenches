`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  // Inputs from sys_monitor (FSM inputs) and slave_monitor (DUT bus)
  uvm_tlm_analysis_fifo #(apb_seq_item) in_fifo;
  uvm_tlm_analysis_fifo #(apb_seq_item) out_fifo;

  // ---------- Golden reference model ----------
  typedef enum { G_IDLE, G_SETUP, G_ACCESS } gstate_e;
  gstate_e gstate;

  // Request currently latched by the golden FSM
  bit [8:0] g_addr;
  bit [7:0] g_wdata;
  bit       g_read;

  // Golden shadow memory (loopback reference)
  bit [7:0] shadow_mem [bit [8:0]];

  // ---------- Counters / results ----------
  int unsigned num_cycles;
  int unsigned num_phase_match;
  int unsigned num_phase_mismatch;   // FSM-phase (PSEL/PENABLE) divergence
  int unsigned num_ghost;            // DUT asserts PSEL while golden = IDLE
  int unsigned num_route_err;        // PSEL1/2 decode wrong, or write routing wrong
  int unsigned num_loop_err;         // read data != shadow
  int unsigned num_writes_checked;
  int unsigned num_reads_checked;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    in_fifo  = new("in_fifo",  this);
    out_fifo = new("out_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item in_tr, out_tr;

    gstate = G_IDLE;

    forever begin
      // Lockstep: one input sample + one bus sample per cycle
      in_fifo.get(in_tr);
      out_fifo.get(out_tr);
      num_cycles++;

      // 1) Compare DUT bus against golden CURRENT state, then
      // 2) Step golden FSM using this cycle's inputs (compare-then-step
      //    replicates the DUT's registered-state one-cycle delay).
      check_cycle(in_tr, out_tr);
      step_golden(in_tr);
    end
  endtask

  // ================= PER-CYCLE COMPARISON =================
  function void check_cycle(apb_seq_item in_tr, apb_seq_item out_tr);
    // ---- Predicted bus outputs for golden's CURRENT state ----
    bit       exp_psel;      // any select asserted
    bit       exp_penable;
    bit       exp_psel1, exp_psel2;

    case (gstate)
      G_IDLE:   begin exp_psel = 0; exp_penable = 0; end
      G_SETUP:  begin exp_psel = 1; exp_penable = 0; end
      G_ACCESS: begin exp_psel = 1; exp_penable = 1; end
    endcase

    // Predicted select routing: RTL decodes PSEL from PADDR[8]
    // ({PSEL1,PSEL2} = addr[8] ? {0,1} : {1,0}), only when selected.
    if (exp_psel) begin
      exp_psel2 = g_addr[8];
      exp_psel1 = ~g_addr[8];
    end else begin
      exp_psel1 = 0;
      exp_psel2 = 0;
    end

    // ---- DUT actual ----
    bit act_psel = out_tr.psel1 | out_tr.psel2;

    // ============ CHECK A: FSM PHASE (PSEL asserted?) ============
    if (act_psel !== exp_psel) begin
      num_phase_mismatch++;
      if (exp_psel === 1'b0 && act_psel === 1'b1) begin
        // Golden says bus should be idle, DUT is driving a select ->
        // this is the ghost / phantom SETUP the RTL FSM produces.
        num_ghost++;
        `uvm_error("SB_GHOST",
          $sformatf("Cycle %0d: GHOST STATE. Spec-correct FSM = %s (PSEL=0), but DUT asserts PSEL (psel1=%0b psel2=%0b, PENABLE=%0b, PADDR=0x%0h). DUT is running a transaction the protocol does not call for.",
                    num_cycles, gstate.name(), out_tr.psel1, out_tr.psel2,
                    out_tr.penable, out_tr.paddr))
      end
      else begin
        // Golden expects a select but DUT drove none -> dropped/absent transaction
        `uvm_error("SB_DROP",
          $sformatf("Cycle %0d: MISSING STATE. Spec-correct FSM = %s (PSEL=1 expected for addr=0x%0h), but DUT PSEL=0. DUT dropped a transaction the protocol requires.",
                    num_cycles, gstate.name(), g_addr))
      end
      return; // phase already diverged; skip deeper checks this cycle
    end

    // ============ CHECK B: PENABLE phase ============
    if (out_tr.penable !== exp_penable) begin
      num_phase_mismatch++;
      `uvm_error("SB_PHASE",
        $sformatf("Cycle %0d: PENABLE mismatch. Spec-correct FSM = %s expects PENABLE=%0b, DUT PENABLE=%0b (PADDR=0x%0h).",
                  num_cycles, gstate.name(), exp_penable, out_tr.penable))
      return;
    end

    // ============ CHECK C: PSEL ROUTING (which slave) ============
    if (exp_psel) begin
      if (out_tr.psel1 !== exp_psel1 || out_tr.psel2 !== exp_psel2) begin
        num_route_err++;
        num_phase_mismatch++;
        `uvm_error("SB_ROUTE_SEL",
          $sformatf("Cycle %0d: PSEL routing wrong for addr=0x%0h (addr[8]=%0b). Expected {PSEL1,PSEL2}={%0b,%0b}, DUT={%0b,%0b}.",
                    num_cycles, g_addr, g_addr[8],
                    exp_psel1, exp_psel2, out_tr.psel1, out_tr.psel2))
        return;
      end
    end

    // Phase (and routing) matched this cycle
    num_phase_match++;

    // ============ DATA CHECKS: only at active completion ============
    // Golden in ACCESS with PREADY high => transfer completes this cycle.
    if (gstate == G_ACCESS && in_tr.pready === 1'b1) begin
      if (~g_read) begin
        // ---- CHECK D: WRITE DATA ROUTING (system data -> bus) ----
        if (out_tr.paddr !== g_addr || out_tr.pwdata !== g_wdata) begin
          num_route_err++;
          `uvm_error("SB_ROUTE_DATA",
            $sformatf("Cycle %0d: Write routing mismatch. System requested addr=0x%0h data=0x%0h, DUT bus PADDR=0x%0h PWDATA=0x%0h.",
                      num_cycles, g_addr, g_wdata, out_tr.paddr, out_tr.pwdata))
        end
        else begin
          shadow_mem[g_addr] = g_wdata;   // commit golden write
        end
        num_writes_checked++;
      end
      else begin
        // ---- CHECK E: READ LOOPBACK (bus data vs shadow) ----
        bit [7:0] exp_rd = shadow_mem.exists(g_addr) ? shadow_mem[g_addr] : 8'h00;
        if (out_tr.rdata !== exp_rd) begin
          num_loop_err++;
          `uvm_error("SB_LOOPBACK",
            $sformatf("Cycle %0d: Read loopback mismatch. addr=0x%0h expected(shadow)=0x%0h, DUT PRDATA=0x%0h.",
                      num_cycles, g_addr, exp_rd, out_tr.rdata))
        end
        num_reads_checked++;
      end
    end
  endfunction

  // ================= GOLDEN FSM NEXT-STATE (spec-correct) =================
  function void step_golden(apb_seq_item in_tr);
    case (gstate)
      G_IDLE: begin
        if (in_tr.transfer) begin
          latch_request(in_tr);
          gstate = G_SETUP;
        end
      end

      G_SETUP: begin
        gstate = G_ACCESS;                 // single-cycle setup
      end

      G_ACCESS: begin
        if (in_tr.pready !== 1'b1)
          gstate = G_ACCESS;               // wait-state hold
        else if (in_tr.transfer) begin
          latch_request(in_tr);            // back-to-back: latch NEW request
          gstate = G_SETUP;
        end
        else
          gstate = G_IDLE;                 // done, no further request
      end
    endcase
  endfunction

  function void latch_request(apb_seq_item in_tr);
    g_read  = in_tr.read;
    g_addr  = in_tr.addr;
    g_wdata = in_tr.wdata;
  endfunction

  // ================= FINAL SUMMARY =================
  function void report_phase(uvm_phase phase);
    string verdict = (num_phase_mismatch == 0 &&
                      num_route_err == 0 &&
                      num_loop_err == 0) ? "PASS" : "FAIL";

    `uvm_info("SB_SUMMARY",
      $sformatf({"\n",
        "==================== APB REFERENCE-MODEL SCOREBOARD ====================\n",
        "  Cycles compared         : %0d\n",
        "  FSM-phase matches        : %0d\n",
        "  FSM-phase mismatches     : %0d\n",
        "     - Ghost states        : %0d   (DUT asserts PSEL, spec = IDLE)\n",
        "     - Dropped/other phase  : %0d\n",
        "  PSEL/data routing errors : %0d\n",
        "  Read loopback errors     : %0d\n",
        "  Writes checked           : %0d\n",
        "  Reads checked            : %0d\n",
        "  ------------------------------------------------------------\n",
        "  RESULT: %s\n",
        "======================================================================="},
        num_cycles, num_phase_match, num_phase_mismatch,
        num_ghost, (num_phase_mismatch - num_ghost),
        num_route_err, num_loop_err,
        num_writes_checked, num_reads_checked, verdict),
      UVM_NONE)
  endfunction

endclass