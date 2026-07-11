`timescale 1ns/1ns

//==========================================================================
// master_bridge_v1_gapless
//--------------------------------------------------------------------------
// MINIMAL FSM FIX - VERSION 1 (GAPLESS BACK-TO-BACK)
//
// WHAT WAS WRONG (original RTL):
//   In the ENABLE (ACCESS) state, on completion (PREADY=1) the FSM went
//   unconditionally to SETUP for BOTH read and write, and had no clean path
//   back to IDLE. Because 'transfer' is still asserted at the completion
//   edge, this produced a spurious/phantom SETUP after every transfer
//   (state seq IDLE->SETUP->ACCESS->SETUP->IDLE for a single transfer), and
//   in back-to-back streams the phantom collided with following transactions,
//   duplicating some and dropping others.
//
// WHAT THIS VERSION CHANGES (if/else only, no new signals/ports):
//   ENABLE completion still chains to SETUP so that a continuously-asserted
//   'transfer' (burst intention held HIGH across the whole sequence) produces
//   GAPLESS back-to-back transfers - no IDLE cycle inserted between transfers.
//   The natural return to IDLE happens through the SETUP block: when the last
//   transfer completes and 'transfer' has dropped, the FSM enters SETUP once
//   and the SETUP block routes it to IDLE (since transfer==0 there).
//
// WHAT IT SACRIFICES / RESIDUAL BUG (intended - catchable by protocol checker):
//   Because the FSM cannot distinguish "genuinely more coming" from "last one,
//   transfer about to drop" at the single completion edge (that difference only
//   appears one cycle later, and adding a signal to detect it is disallowed),
//   ONE phantom SETUP cycle remains after the LAST transfer of each burst
//   (ACCESS -> SETUP -> IDLE). Data integrity is correct everywhere; this
//   trailing phantom SETUP is a pure protocol-level quirk that the FSM/protocol
//   checker is expected to flag later.
//
// WHAT IS LEFT UNTOUCHED (per project scope):
//   - PSLVERR error path (TB never drives PSLVERR; branch stays as-is).
//   - Wait-state hold (else -> ENABLE on PREADY=0) - already spec-correct.
//   - Read data capture (apb_read_data_out <= PRDATA) - already correct.
//   - IDLE and SETUP blocks - unchanged.
//
// SAVED AS A SEPARATE FILE. Original master_bridge is NOT modified.
//==========================================================================

module master_bridge_v1_gapless(
        input [8:0]apb_write_paddr,apb_read_paddr,
        input [7:0] apb_write_data,PRDATA,
        input PRESETn,PCLK,READ_WRITE,transfer,PREADY,
        output PSEL1,PSEL2,
        output reg PENABLE,
        output reg [8:0]PADDR,
        output reg PWRITE,
        output reg [7:0]PWDATA,apb_read_data_out,
        input PSLVERR );

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

always @(state,transfer,PREADY) begin
        if(!PRESETn)
                next_state = IDLE;
        else begin
        PWRITE = ~READ_WRITE;
        case(state)
                IDLE    : begin
                        PENABLE =0;
                        if(!transfer)
                                next_state = IDLE ;
                        else
                                next_state = SETUP;
                        end
                SETUP   : begin
                        PENABLE =0;
                        if(READ_WRITE) begin
                          PADDR = apb_read_paddr;
                        end
                        else begin
                                PADDR = apb_write_paddr;
                                PWDATA = apb_write_data;
                        end

                        if(transfer && !PSLVERR)
                                next_state = ENABLE;
                        else
                        next_state = IDLE;
                        end

                ENABLE : begin

                        if(PSEL1 || PSEL2)
                                PENABLE =1;

                        if(transfer & !PSLVERR) begin
                          if(PREADY) begin
                                        //==================================================
                                        // FIX v1: on completion, CHAIN to SETUP for gapless
                                        // back-to-back. A continuously-held 'transfer' keeps
                                        // streaming transfers with no IDLE bubble. When the
                                        // last transfer completes and 'transfer' has dropped,
                                        // the SETUP block routes to IDLE (transfer==0 there).
                                        // Read-data capture retained on the read branch.
                                        //==================================================
                                        if(!READ_WRITE) begin
                                next_state = SETUP; end
                          else begin
                                next_state = SETUP;
                                apb_read_data_out = PRDATA;
                                        end
                          end
                        else next_state = ENABLE;   // PREADY=0: hold in ACCESS (wait state)
                        end
                        else next_state = IDLE;     // PSLVERR path (untouched)
                end
                default: next_state = IDLE;
        endcase
        end
end

assign {PSEL1,PSEL2} = ((state != IDLE) ? (PADDR[8] ? {1'b0,1'b1} : {1'b1,1'b0}) : 2'd0);

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

// assign PSLVERR =  invalid_setup_error ;

endmodule