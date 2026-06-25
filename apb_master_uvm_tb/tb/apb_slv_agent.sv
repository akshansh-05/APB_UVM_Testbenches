`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_slv_agent extends uvm_agent;

  `uvm_component_utils(apb_slv_agent)

  apb_slv_driver    drv;
  apb_slv_monitor   mon;

  function new(string name = "apb_slv_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_slv_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_slv_driver::type_id::create("drv", this);
    end
  endfunction

endclass
