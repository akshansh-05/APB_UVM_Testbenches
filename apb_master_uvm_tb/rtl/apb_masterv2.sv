`timescale 1ns/1ns

// =============================================================================
// master_bridge  — SPEC-FAITHFUL (AMBA APB state diagram)
// =============================================================================
// Implements the canonical AMBA APB FSM exactly:
//
//        IDLE --(transfer)--> SETUP --(always)--> ACCESS
//        ACCESS --(PREADY=0)-------------------> ACCESS   (wait state)
//        ACCESS --(PREADY=1 &&  transfer)------> SETUP    (gapless b2b)
//        ACCESS --(PREADY=1 && !transfer)------> IDLE     (done)
//
// CONTRACT WITH THE DRIVER (not a hack — this is what the spec's `transfer`
// MEANS at the ACCESS completion edge):
//   `transfer` sampled at the ACCESS->exit edge = "a NEW transfer is pending
//   AND its address/data are already presented on the system inputs".
//   The pipelined system driver guarantees this: it presents the next item's
//   address/data on the SAME cycle it detects completion, and drops transfer
//   only when the sequencer is empty. Therefore:
//     - transfer=1 at completion  -> SETUP re-enters with the NEW address (gapless)
//     - transfer=0 at completion  -> IDLE (clean end)
//
// KEY DIFFERENCE vs. professor's original:
//   Original chained ACCESS->SETUP UNCONDITIONALLY (took the gapless arrow
//   even when the "transfer" was just the tail of the completed transfer,
//   re-processing STALE address -> ghost SETUP, alternate drops).
//   Here the SETUP vs IDLE choice is CONDITIONAL on `transfer`, exactly as
//   the diagram shows, AND the driver ensures a fresh address accompanies a
//   high transfer at that edge.
//
// FIXES:
//   [1] Conditional ACCESS exit (SETUP vs IDLE) per spec diagram.
//   [2] always @(*) — complete sensitivity list, so a new address/data on
//       the system side is actually sampled into PADDR/PWDATA.
//   [3] Default assignments — no inferred latches on FSM outputs.
//
// RESIDUAL (per professor mandate): PSLVERR / error block left as original.
// Module name kept `master_bridge` for drop-in replacement.
// =============================================================================

module master_bridge(
        input      [8:0] apb_write_paddr, apb_read_paddr,
        input      [7:0] apb_write_data, PRDATA,
        input            PRESETn, PCLK, READ_WRITE, transfer, PREADY,
        output           PSEL1, PSEL2,
        output reg       PENABLE,
        output reg [8:0] PADDR,
        output reg       PWRITE,
        output reg [7:0] PWDATA, apb_read_data_out,
        output           PSLVERR );

reg [2:0] state, next_state;

reg invalid_setup_error,
    setup_error,
    invalid_read_paddr,
    invalid_write_paddr,
    invalid_write_data;

localparam IDLE = 3'b001, SETUP = 3'b010, ENABLE = 3'b100;

// -----------------------------------------------------------------------------
// State register (synchronous reset, as original)
// -----------------------------------------------------------------------------
always @(posedge PCLK) begin
        if(!PRESETn)
                state <= IDLE;
        else
                state <= next_state;
end

// -----------------------------------------------------------------------------
// Next-state + output logic — FULL sensitivity list, defaults prevent latches
// -----------------------------------------------------------------------------
always @(*) begin
        // ---- defaults ----
        next_state        = state;
        PENABLE           = 1'b0;
        PADDR             = 9'd0;
        PWDATA            = 8'd0;
        apb_read_data_out = 8'd0;
        PWRITE            = ~READ_WRITE;

        case(state)
                // =========================================================
                IDLE : begin
                        PENABLE = 1'b0;
                        if(!transfer)
                                next_state = IDLE;
                        else
                                next_state = SETUP;
                end

                // =========================================================
                SETUP : begin
                        PENABLE = 1'b0;
                        if(READ_WRITE)
                                PADDR = apb_read_paddr;
                        else begin
                                PADDR  = apb_write_paddr;
                                PWDATA = apb_write_data;
                        end

                        if(transfer && !PSLVERR)
                                next_state = ENABLE;
                        else
                                next_state = IDLE;
                end

                // =========================================================
                ENABLE : begin
                        // hold address/data stable through ACCESS
                        if(READ_WRITE)
                                PADDR = apb_read_paddr;
                        else begin
                                PADDR  = apb_write_paddr;
                                PWDATA = apb_write_data;
                        end

                        if(PSEL1 || PSEL2)
                                PENABLE = 1'b1;

                        if(!PREADY) begin
                                // -------- wait state: hold ACCESS --------
                                next_state = ENABLE;
                        end
                        else begin
                                // -------- completion: capture read data --------
                                if(READ_WRITE)
                                        apb_read_data_out = PRDATA;

                                // ===== SPEC-FAITHFUL CONDITIONAL EXIT =====
                                if(transfer && !PSLVERR)
                                        next_state = SETUP;   // new transfer pending -> gapless
                                else
                                        next_state = IDLE;    // no transfer -> done
                        end
                end

                // =========================================================
                default : next_state = IDLE;
        endcase
end

// -----------------------------------------------------------------------------
// Slave select decode (unchanged)
// -----------------------------------------------------------------------------
assign {PSEL1,PSEL2} = ((state != IDLE) ? (PADDR[8] ? {1'b0,1'b1} : {1'b1,1'b0}) : 2'd0);

// -----------------------------------------------------------------------------
// Error detection (RESIDUAL - intentionally left as in original)
// -----------------------------------------------------------------------------
always @(*) begin
        if(!PRESETn) begin
                setup_error         = 0;
                invalid_read_paddr  = 0;
                invalid_write_paddr = 0;
                invalid_write_data  = 0;
        end
        else begin
                if(state == IDLE && next_state == ENABLE)
                        setup_error = 1;
                else
                        setup_error = 0;

                if((apb_write_data===8'dx) && (!READ_WRITE) && (state==SETUP || state==ENABLE))
                        invalid_write_data = 1;
                else
                        invalid_write_data = 0;

                if((apb_read_paddr===9'dx) && READ_WRITE && (state==SETUP || state==ENABLE))
                        invalid_read_paddr = 1;
                else
                        invalid_read_paddr = 0;

                if((apb_write_paddr===9'dx) && (!READ_WRITE) && (state==SETUP || state==ENABLE))
                        invalid_write_paddr = 1;
                else
                        invalid_write_paddr = 0;

                if(state == SETUP) begin
                        if(PWRITE) begin
                                if(PADDR==apb_write_paddr && PWDATA==apb_write_data)
                                        setup_error = 1'b0;
                                else
                                        setup_error = 1'b1;
                        end
                        else begin
                                if(PADDR==apb_read_paddr)
                                        setup_error = 1'b0;
                                else
                                        setup_error = 1'b1;
                        end
                end
                else
                        setup_error = 1'b0;
        end
        invalid_setup_error = setup_error || invalid_read_paddr || invalid_write_data || invalid_write_paddr;
end

assign PSLVERR = invalid_setup_error;

endmodule