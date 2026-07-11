`timescale 1ns/1ns

// =============================================================================
// master_bridge  — FULLY FIXED (spec-faithful AMBA APB FSM)
// =============================================================================
// Based on the professor's ORIGINAL RTL. Same ports, same PSLVERR/error block
// (left as residual). Two real DUT bugs eliminated, one supporting cleanup:
//
//   BUG 1 - Ghost SETUP (unconditional ENABLE->SETUP chaining):
//       ORIGINAL: on PREADY, both read and write did next_state = SETUP,
//       re-entering SETUP for the just-completed transfer every burst cycle.
//       FIX: implement the AMBA APB spec's CONDITIONAL ACCESS exit:
//            PREADY=0            -> ENABLE  (wait state)
//            PREADY=1 &&  transfer -> SETUP (genuine gapless b2b)
//            PREADY=1 && !transfer -> IDLE  (done)
//       Now SETUP is re-entered only when a NEW transfer is actually pending.
//
//   BUG 2 - Incomplete sensitivity list:
//       ORIGINAL: always @(state,transfer,PREADY) — missed address/data/
//       READ_WRITE, so a new address could fail to be sampled.
//       FIX: always @(*).
//
//   CLEANUP - Latch avoidance:
//       Default assignments at top of the combinational block so PADDR/
//       PWDATA/PWRITE/PENABLE/apb_read_data_out never infer latches.
//
// RESIDUAL (unchanged, per professor mandate): the PSLVERR / error-detection
// block is preserved verbatim for the protocol checker to exercise.
//
// Module name kept `master_bridge` for drop-in replacement.
// =============================================================================

module master_bridge(
        input [8:0]apb_write_paddr,apb_read_paddr,
        input [7:0] apb_write_data,PRDATA,
        input PRESETn,PCLK,READ_WRITE,transfer,PREADY,
        output PSEL1,PSEL2,
        output reg PENABLE,
        output reg [8:0]PADDR,
        output reg PWRITE,
        output reg [7:0]PWDATA,apb_read_data_out,
        output PSLVERR );

reg [2:0] state, next_state;

reg invalid_setup_error,
        setup_error,
        invalid_read_paddr,
        invalid_write_paddr,
        invalid_write_data ;

localparam IDLE = 3'b001, SETUP = 3'b010, ENABLE = 3'b100 ;


always @(posedge PCLK)
begin
        if(!PRESETn)
                state <= IDLE;
        else
                state <= next_state;
end

// -----------------------------------------------------------------------------
// FSM combinational logic — full sensitivity list + defaults (no latches)
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
                IDLE : begin
                        PENABLE = 1'b0;
                        if(!transfer)
                                next_state = IDLE ;
                        else
                                next_state = SETUP;
                end

                SETUP : begin
                        PENABLE = 1'b0;
                        if(READ_WRITE) begin
                                PADDR = apb_read_paddr;
                        end
                        else begin
                                PADDR  = apb_write_paddr;
                                PWDATA = apb_write_data;
                        end

                        // Spec diagram: SETUP -> ACCESS is UNCONDITIONAL (bold
                        // arrow, no condition). Once PSEL is asserted the
                        // transfer is committed and MUST complete its ACCESS
                        // phase. Do NOT gate this on `transfer` (gating it is
                        // what dropped the tail transaction).
                        // !PSLVERR retained only as an error-abort guard.
                        if(!PSLVERR)
                                next_state = ENABLE;
                        else
                                next_state = IDLE;
                end

                ENABLE : begin
                        // hold address/data stable through ACCESS
                        if(READ_WRITE) begin
                                PADDR = apb_read_paddr;
                        end
                        else begin
                                PADDR  = apb_write_paddr;
                                PWDATA = apb_write_data;
                        end

                        if(PSEL1 || PSEL2)
                                PENABLE = 1'b1;

                        if(!PREADY) begin
                                // wait state: hold ACCESS, keep PENABLE high
                                next_state = ENABLE;
                        end
                        else begin
                                // completion
                                if(READ_WRITE)
                                        apb_read_data_out = PRDATA;

                                // ===== SPEC-FAITHFUL CONDITIONAL EXIT =====
                                if(transfer && !PSLVERR)
                                        next_state = SETUP;   // new transfer pending -> gapless
                                else
                                        next_state = IDLE;    // no transfer -> done
                        end
                end

                default: next_state = IDLE;
        endcase
end

assign {PSEL1,PSEL2} = ((state != IDLE) ? (PADDR[8] ? {1'b0,1'b1} : {1'b1,1'b0}) : 2'd0);

// -----------------------------------------------------------------------------
// Error detection (RESIDUAL - preserved from original)
// -----------------------------------------------------------------------------
always @(*) begin
        if(!PRESETn) begin
                setup_error =0;
                invalid_read_paddr = 0;
                invalid_write_paddr = 0;
                invalid_write_paddr =0 ;
        end
        else begin
                begin
                if(state == IDLE && next_state == ENABLE)
                        setup_error = 1;
                else setup_error = 0;
                end

                begin
                if((apb_write_data===8'dx) && (!READ_WRITE) && (state==SETUP || state==ENABLE))
                        invalid_write_data =1;
                else invalid_write_data = 0;
                end

                begin
                if((apb_read_paddr===9'dx) && READ_WRITE && (state==SETUP || state==ENABLE))
                        invalid_read_paddr = 1;
                else  invalid_read_paddr = 0;
                end

                begin
                if((apb_write_paddr===9'dx) && (!READ_WRITE) && (state==SETUP || state==ENABLE))
                        invalid_write_paddr =1;
                else invalid_write_paddr =0;
                end

                begin
                if(state == SETUP) begin
                        if(PWRITE) begin
                          if(PADDR==apb_write_paddr && PWDATA==apb_write_data)
                                setup_error=1'b0;
                          else
                                setup_error=1'b1;
                        end
                        else begin
                          if (PADDR==apb_read_paddr)
                                setup_error=1'b0;
                          else
                                setup_error=1'b1;
                        end
                end
                else setup_error=1'b0;
                end
        end
        invalid_setup_error = setup_error ||  invalid_read_paddr || invalid_write_data || invalid_write_paddr ;
end

 assign PSLVERR =  invalid_setup_error ;

endmodule