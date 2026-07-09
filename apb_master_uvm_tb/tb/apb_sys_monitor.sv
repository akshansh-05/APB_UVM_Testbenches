`include "uvm_macros.svh"
import uvm_pkg::*;

class sys_monitor extends uvm_monitor;
  `uvm_component_utils(sys_monitor)

  virtual apb_if vif;

  // Broadcasts one input-side sample per clock to the scoreboard
  uvm_analysis_port #(apb_seq_item) ap_in;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap_in = new("ap_in", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SYS_MON", "Virtual interface not set for sys_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item tr;

    forever begin
      @(vif.sys_monitor_cb);

      // Only sample when out of reset, so input/output monitors start in lockstep
      if (vif.PRESETn === 1'b1) begin
        tr = apb_seq_item::type_id::create("in_tr");

        // FSM inputs the DUT sees this cycle
        tr.transfer = vif.sys_monitor_cb.transfer;
        tr.read     = vif.sys_monitor_cb.READ_WRITE;   // 1 = read, 0 = write

        // Master presents read or write address depending on direction
        tr.addr     = vif.sys_monitor_cb.READ_WRITE ?
                      vif.sys_monitor_cb.apb_read_paddr :
                      vif.sys_monitor_cb.apb_write_paddr;

        tr.wdata    = vif.sys_monitor_cb.apb_write_data;

        // PREADY is a slave-driven FSM input (needed for wait-state modelling)
        tr.pready   = vif.sys_monitor_cb.PREADY;

        `uvm_info("SYS_MON",
          $sformatf("transfer=%0b read=%0b addr=0x%0h wdata=0x%0h pready=%0b",
                    tr.transfer, tr.read, tr.addr, tr.wdata, tr.pready),
          UVM_MEDIUM)

        ap_in.write(tr);
      end
    end
  endtask

endclass