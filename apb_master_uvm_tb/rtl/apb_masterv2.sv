`timescale 1ns/1ns

// =============================================================================
// master_bridge  (REGISTERED ADDRESS/DATA PATH)
// =============================================================================
// System-to-APB Master Bridge, 3-state one-hot FSM.
//
// EVOLUTION FROM PREVIOUS FIXED VERSION:
//   Previous version drove PADDR/PWDATA/PWRITE combinationally in the FSM
//   block -> the APB address tracked the system input on the SAME posedge
//   (zero master latency). Real hardware must SAMPLE the system request and
//   present the registered APB address one cycle later.
//
//   THIS VERSION registers PADDR/PWDATA/PWRITE on the IDLE->SETUP transition
//   (i.e. the clock edge that enters SETUP), then HOLDS them stable through
//   ACCESS. Result:
//       system request valid @ cycle N (IDLE, transfer asserted)
//       PADDR/PWDATA valid    @ cycle N+1 (SETUP)  -- 1-cycle master latency
//       held stable through   @ cycle N+2 (ACCESS)
//   This is APB-legal (addr valid in SETUP, held through ACCESS) AND models
//   realistic registered master timing.
//
// CARRIED-OVER FIXES:
//   [1] Phantom SETUP removed: ENABLE completion -> IDLE (clean bubble b2b).
//   [2] Full sensitivity list via @(*) on next-state logic.
//   [3] No inferred latches: PADDR/PWDATA/PWRITE now properly registered;
//       PENABLE defaulted in combinational block.
//
// DELIBERATE RESIDUAL (per professor mandate):
//   - PSLVERR / error-detection path left as-is for the protocol checker.
//   - Module name kept `master_bridge` for drop-in replacement.
//
// NOTE - RE-VERIFICATION REQUIRED:
//   This changes output TIMING vs. the combinational version. Confirm the
//   scoreboard Expected/Actual pairing still aligns:
//     - System monitor: Expected sampled at SETUP-entry (system-side) -> OK.
//     - Bus monitor: Actual sampled at completion edge (PENABLE&&PREADY);
//       registered PADDR is stable by then -> OK.
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
// State register (synchronous reset, as in original)
// -----------------------------------------------------------------------------
always @(posedge PCLK) begin
        if(!PRESETn)
                state <= IDLE;
        else
                state <= next_state;
end

// -----------------------------------------------------------------------------
// Next-state logic  (pure combinational, full sensitivity list)
//   Only computes next_state + PENABLE. Address/data are NOT driven here
//   anymore -- they are registered in the sequential block below.
// -----------------------------------------------------------------------------
always @(*) begin
        next_state = state;
        PENABLE    = 1'b0;

        case(state)
                IDLE : begin
                        PENABLE = 1'b0;
                        if(!transfer)
                                next_state = IDLE;
                        else
                                next_state = SETUP;
                end

                SETUP : begin
                        PENABLE = 1'b0;
                        if(transfer && !PSLVERR)
                                next_state = ENABLE;
                        else
                                next_state = IDLE;
                end

                ENABLE : begin
                        if(PSEL1 || PSEL2)
                                PENABLE = 1'b1;

                        if(transfer & !PSLVERR) begin
                                if(PREADY)
                                        next_state = IDLE;   // phantom SETUP fix
                                else
                                        next_state = ENABLE; // wait state hold
                        end
                        else begin
                                next_state = IDLE;
                        end
                end

                default : next_state = IDLE;
        endcase
end

// -----------------------------------------------------------------------------
// REGISTERED address / data / control path
//   Latch the system request on the edge that ENTERS SETUP (IDLE->SETUP),
//   giving 1-cycle master latency. Hold stable through ACCESS. Clear on reset.
// -----------------------------------------------------------------------------
always @(posedge PCLK) begin
        if(!PRESETn) begin
                PADDR             <= 9'd0;
                PWDATA            <= 8'd0;
                PWRITE            <= 1'b0;
                apb_read_data_out <= 8'd0;
        end
        else begin
                // Sample request as the FSM commits to SETUP (this cycle is
                // IDLE with transfer asserted -> next cycle is SETUP).
                if(state == IDLE && transfer) begin
                        PWRITE <= ~READ_WRITE;
                        if(READ_WRITE) begin
                                PADDR  <= apb_read_paddr;
                        end
                        else begin
                                PADDR  <= apb_write_paddr;
                                PWDATA <= apb_write_data;
                        end
                end
                // else: hold PADDR/PWDATA/PWRITE stable through SETUP & ACCESS.

                // Capture read data at completion edge.
                if(state == ENABLE && (PSEL1 || PSEL2) && PENABLE && PREADY && READ_WRITE) begin
                        apb_read_data_out <= PRDATA;
                end
        end
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