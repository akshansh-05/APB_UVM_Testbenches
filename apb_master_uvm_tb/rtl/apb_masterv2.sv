`timescale 1ns/1ns

//==========================================================================
// master_bridge_v2_clean
//--------------------------------------------------------------------------
// MINIMAL FSM FIX - VERSION 2 (PROTOCOL-CLEAN EXIT, IDLE BUBBLE ON B2B)
//
// WHAT WAS WRONG (original RTL):
//   In the ENABLE (ACCESS) state, on completion (PREADY=1) the FSM went
//   unconditionally to SETUP for BOTH read and write, with no clean path to
//   IDLE. Since 'transfer' is still asserted at the completion edge, this
//   produced a spurious/phantom SETUP after every transfer and, in back-to-
//   back streams, duplicated some transactions and dropped others.
//
// WHAT THIS VERSION CHANGES (if/else only, no new signals/ports):
//   ENABLE completion now goes to IDLE for both read and write. This removes
//   the phantom SETUP entirely - the ACCESS-exit becomes protocol-clean
//   (ACCESS -> IDLE on completion, exactly per the APB state diagram for the
//   no-immediate-successor case). If 'transfer' is still asserted (burst),
//   the IDLE block re-dispatches to SETUP on the next cycle.
//
// WHAT IT SACRIFICES / RESIDUAL BEHAVIOUR:
//   Back-to-back transfers are NOT gapless: exactly ONE IDLE cycle is inserted
//   between consecutive transfers of a burst
//   (IDLE -> SETUP -> ACCESS -> IDLE -> SETUP -> ACCESS -> ...).
//   This is spec-legal (an IDLE cycle between transfers is permitted) and data
//   integrity is fully correct. The tradeoff vs. Version 1 is: this version is
//   protocol-clean on the ACCESS exit (no phantom SETUP) but not gapless;
//   Version 1 is gapless but leaves a trailing phantom SETUP per burst.
//
// WHAT IS LEFT UNTOUCHED (per project scope):
//   - PSLVERR error path (TB never drives PSLVERR; branch stays as-is).
//   - Wait-state hold (else -> ENABLE on PREADY=0) - already spec-correct.
//   - Read data capture (apb_read_data_out <= PRDATA) - already correct.
//   - IDLE and SETUP blocks - unchanged.
//
// SAVED AS A SEPARATE FILE. Original master_bridge is NOT modified.
//==========================================================================

module master_bridge_v2_clean(
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
                                        // FIX v2: on completion, go to IDLE (protocol-clean
                                        // ACCESS exit, no phantom SETUP). If 'transfer' is
                                        // still held (burst), the IDLE block re-dispatches to
                                        // SETUP next cycle - inserting one IDLE bubble between
                                        // back-to-back transfers. Read-data capture retained.
                                        //==================================================
                                        if(!READ_WRITE) begin
                                next_state = IDLE; end
                          else begin
                                next_state = IDLE;
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