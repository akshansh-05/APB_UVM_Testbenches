`timescale 1ns/1ns

// =============================================================================
// master_bridge  (FIXED)
// =============================================================================
// System-to-APB Master Bridge, 3-state one-hot FSM.
//
// FIXES APPLIED (vs. original professor RTL):
//   [1] CORE BUG - Phantom SETUP on ACCESS exit:
//         ENABLE-state completion now returns to IDLE instead of
//         unconditionally chaining to SETUP. This removes the spurious
//         SETUP that duplicated the just-completed transfer and starved
//         the next one (the 10-write -> 5-write alternate-drop failure).
//   [2] Incomplete sensitivity list -> always @(*).
//   [3] Latch inference on FSM outputs -> default assignments at top of
//         the combinational block.
//   [4] Redundant async-reset branch removed from the combinational block
//         (reset is handled cleanly in the sequential block).
//
// DELIBERATELY LEFT AS RESIDUAL (per professor's mandate):
//   - PSLVERR / error-detection path is not exercised by the current TB
//     and is intentionally left as-is for the protocol/FSM checker to catch.
//   - Module name kept as `master_bridge` for drop-in replacement in tb_top.
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
// State register (synchronous, sync reset as in original)
// -----------------------------------------------------------------------------
always @(posedge PCLK) begin
        if(!PRESETn)
                state <= IDLE;
        else
                state <= next_state;
end

// -----------------------------------------------------------------------------
// Next-state + output logic
//   FIX [2]: full sensitivity list via @(*)
//   FIX [3]: default assignments prevent inferred latches on all outputs
//   FIX [4]: no reset branch here; reset lives in the sequential block
// -----------------------------------------------------------------------------
always @(*) begin
        // ---- Defaults (hold nothing implicitly -> no latches) ----
        next_state        = state;
        PENABLE           = 1'b0;
        PADDR             = 9'd0;
        PWDATA            = 8'd0;
        apb_read_data_out = 8'd0;
        PWRITE            = ~READ_WRITE;

        case(state)
                // -------------------------------------------------
                IDLE : begin
                        PENABLE = 1'b0;
                        if(!transfer)
                                next_state = IDLE;
                        else
                                next_state = SETUP;
                end

                // -------------------------------------------------
                SETUP : begin
                        PENABLE = 1'b0;
                        if(READ_WRITE) begin
                                PADDR = apb_read_paddr;
                        end
                        else begin
                                PADDR  = apb_write_paddr;
                                PWDATA = apb_write_data;
                        end

                        if(transfer && !PSLVERR)
                                next_state = ENABLE;
                        else
                                next_state = IDLE;
                end

                // -------------------------------------------------
                ENABLE : begin
                        // hold address/data stable through ACCESS phase
                        if(READ_WRITE) begin
                                PADDR = apb_read_paddr;
                        end
                        else begin
                                PADDR  = apb_write_paddr;
                                PWDATA = apb_write_data;
                        end

                        if(PSEL1 || PSEL2)
                                PENABLE = 1'b1;

                        if(transfer & !PSLVERR) begin
                                if(PREADY) begin
                                        // ---- CORE FIX [1] ----
                                        // Completion -> IDLE (NOT SETUP).
                                        // Removes phantom SETUP; the next
                                        // transfer starts fresh from IDLE.
                                        if(READ_WRITE)
                                                apb_read_data_out = PRDATA;
                                        next_state = IDLE;
                                end
                                else begin
                                        // wait state: hold ENABLE, keep PENABLE high
                                        next_state = ENABLE;
                                end
                        end
                        else begin
                                next_state = IDLE;
                        end
                end

                // -------------------------------------------------
                default : next_state = IDLE;
        endcase
end

// -----------------------------------------------------------------------------
// Slave select decode (unchanged)
// -----------------------------------------------------------------------------
assign {PSEL1,PSEL2} = ((state != IDLE) ? (PADDR[8] ? {1'b0,1'b1} : {1'b1,1'b0}) : 2'd0);

// -----------------------------------------------------------------------------
// Error detection (RESIDUAL - intentionally left as in original)
// Left for the protocol/FSM checker to exercise. Not driven by current TB.
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