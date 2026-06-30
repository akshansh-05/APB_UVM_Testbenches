//==================================================================
// apb_driver.sv  --  APB master driver
//------------------------------------------------------------------
// Robust to EVERY traffic scenario in the vPLAN:
//   * idle gaps        (no item available -> drive idle)
//   * single transfer  (SETUP -> ACCESS -> done)
//   * back-to-back     (next SETUP starts the cycle the previous
//                       ACCESS completes -> zero idle gap)
//   * wait states      (PREADY held low -> hold ACCESS, signals stable)
//   * reset any time   (abort cleanly, release the sequence, go idle)
//
// Beginner-safe: simple 3-state FSM, one clock per loop. No fork/join,
// no clocking blocks, no RAL, no advanced macros.
//==================================================================
class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;     // handle to the DUT pins
  apb_seq_item   req;     // current transaction in flight

  // the only APB master states we ever need
  typedef enum {ST_IDLE, ST_SETUP, ST_ACCESS} state_e;
  state_e state;
  bit     have_item;      // 1 = a transaction is currently in flight

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Virtual interface 'vif' not set for the driver")
  endfunction

  task run_phase(uvm_phase phase);
    state     = ST_IDLE;
    have_item = 1'b0;
    drive_idle();                       // safe defaults before any clock

    forever begin
      @(posedge vif.PCLK);

      //------------------------------------------------------------
      // RESET has the highest priority. If it hits mid-transfer we
      // abort, release the sequence (item_done) so it never hangs,
      // and force the bus idle.
      //------------------------------------------------------------
      if (vif.PRESETn === 1'b0) begin
        drive_idle();
        if (have_item) begin
          seq_item_port.item_done();
          have_item = 1'b0;
        end
        state = ST_IDLE;
        continue;
      end

      //------------------------------------------------------------
      // Normal APB master state machine
      //------------------------------------------------------------
      case (state)

        // ---- IDLE: try to fetch a transaction ----
        ST_IDLE: begin
          seq_item_port.try_next_item(req);   // non-blocking
          if (req != null) begin
            have_item = 1'b1;
            drive_setup(req);                 // SETUP phase this cycle
            state = ST_SETUP;
          end
          else begin
            drive_idle();                     // nothing to do -> idle
            state = ST_IDLE;
          end
        end

        // ---- SETUP: assert PENABLE to enter ACCESS ----
        ST_SETUP: begin
          vif.PENABLE <= 1'b1;
          state = ST_ACCESS;
        end

        // ---- ACCESS: complete when slave asserts PREADY ----
        ST_ACCESS: begin
          if (vif.PREADY === 1'b1) begin
            if (req.pwrite === 1'b0)
              req.prdata = vif.PRDATA;        // capture read data
            seq_item_port.item_done();
            have_item = 1'b0;

            // Immediately start the next transfer if the sequence has
            // one ready -> this is what gives true back-to-back timing.
            seq_item_port.try_next_item(req);
            if (req != null) begin
              have_item = 1'b1;
              drive_setup(req);
              state = ST_SETUP;
            end
            else begin
              drive_idle();
              state = ST_IDLE;
            end
          end
          else begin
            // slave not ready: hold ACCESS, keep all signals stable
            state = ST_ACCESS;
          end
        end

      endcase
    end
  endtask

  // Drive the SETUP-phase values for a transaction (PENABLE stays low).
  task drive_setup(apb_seq_item tr);
    vif.PSEL    <= 1'b1;
    vif.PENABLE <= 1'b0;
    vif.PWRITE  <= tr.pwrite;
    vif.PADDR   <= tr.paddr;
    vif.PWDATA  <= (tr.pwrite === 1'b1) ? tr.pwdata : 8'h00;
  endtask

  // Drive the bus to a clean idle state.
  task drive_idle();
    vif.PSEL    <= 1'b0;
    vif.PENABLE <= 1'b0;
    vif.PWRITE  <= 1'b0;
    vif.PADDR   <= 8'h00;
    vif.PWDATA  <= 8'h00;
  endtask

endclass