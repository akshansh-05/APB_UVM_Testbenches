//==================================================================
// apb_monitor.sv  --  APB passive monitor
//------------------------------------------------------------------
// Sends exactly ONE apb_seq_item to the scoreboard per COMPLETED
// transfer -- captured at the single edge where the slave is in
// ACCESS and ready (PSEL & PENABLE & PREADY all high).
//
// Why this is robust to everything:
//   * back-to-back : each transfer has its own completion edge, so
//                    each is captured once -- no merging.
//   * wait states  : during waits PREADY is low, so we don't capture
//                    until the real completion edge -> no duplicates.
//   * reset/abort  : an aborted transfer never reaches PREADY=1, so
//                    it is simply never sent. PRESETn is also checked.
//
// Beginner-safe: one sampling point, no fork/join, no clocking blocks.
//==================================================================
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_seq_item) mon_ap;   // -> scoreboard

  function new(string name, uvm_component parent);
    super.new(name, parent);
    mon_ap = new("mon_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "Virtual interface 'vif' not set for the monitor")
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item tr;
    forever begin
      @(posedge vif.PCLK);

      // A transfer is valid/complete only in ACCESS with the slave
      // ready, and only when we are not in reset.
      if (vif.PRESETn === 1'b1 &&
          vif.PSEL    === 1'b1 &&
          vif.PENABLE === 1'b1 &&
          vif.PREADY  === 1'b1) begin

        tr        = apb_seq_item::type_id::create("tr");
        tr.paddr  = vif.PADDR;
        tr.pwrite = vif.PWRITE;
        tr.pwdata = vif.PWDATA;
        tr.prdata = vif.PRDATA;     // meaningful on reads (pwrite==0)

        mon_ap.write(tr);           // broadcast to subscribers
      end
    end
  endtask

endclass