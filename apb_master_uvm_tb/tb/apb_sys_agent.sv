`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_sys_agent extends uvm_agent;

  `uvm_component_utils(apb_sys_agent)

  apb_sys_driver    drv;
  apb_sys_monitor   mon;
  apb_sequencer     sqr;

  function new(string name = "apb_sys_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_sys_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_sys_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass
