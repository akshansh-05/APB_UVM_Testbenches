`timescale 1ns/1ns

// =============================================================================
// master_bridge  — MINIMAL GHOST-SETUP FIX
// =============================================================================
// This is the professor's ORIGINAL RTL with exactly ONE functional change:
// the ENABLE-state completion transition now goes to IDLE instead of SETUP.
//
// Rationale (proven with protocol-clean drivers):
//   The system driver holds `transfer` HIGH across the burst (legal APB
//   master behaviour) and paces off PENABLE&&PREADY. At the ACCESS
//   completion edge the original FSM sampled transfer=1 and re-entered
//   SETUP for the just-completed transfer, using STALE address/data (the
//   next item's values are not yet driven). Result: alternate transactions
//   duplicated/dropped (10 writes -> 5 on the bus).
//
//   Going ENABLE->IDLE on completion removes the ghost SETUP. Each transfer
//   restarts cleanly from IDLE (one-cycle bubble between b2b transfers,
//   which is spec-legal APB). All 10 addresses/data now reach the bus.
//
// EVERYTHING ELSE IS UNCHANGED from the professor's original:
//   - Same ports, no new signals.
//   - Combinational PADDR/PWDATA path (unchanged).
//   - Sensitivity list left as-is (see NOTE below).
//   - PSLVERR / error-detection block untouched (residual for protocol chk).
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
        // integer i,count;

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

// NOTE: sensitivity list kept as original @(state,transfer,PREADY). It is
// technically incomplete but left unchanged to keep this a MINIMAL diff.
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
                                        if(!READ_WRITE) begin
                                // ===== ONLY CHANGE: SETUP -> IDLE (ghost fix) =====
                                next_state = IDLE; end
                          else begin
                                // ===== ONLY CHANGE: SETUP -> IDLE (ghost fix) =====
                                next_state = IDLE;
                                apb_read_data_out = PRDATA;
                                        end
                          end
                        else next_state = ENABLE;
                        end
                        else next_state = IDLE;
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

 assign PSLVERR =  invalid_setup_error ;

endmodule