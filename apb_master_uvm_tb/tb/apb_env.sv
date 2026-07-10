`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_env extends uvm_env;

  `uvm_component_utils(apb_env)

  apb_sys_agent    sys_agent;
  apb_slv_agent    slv_agent;
  apb_scoreboard   scoreboard;

  function new(string name = "apb_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sys_agent  = apb_sys_agent::type_id::create("sys_agent", this);
    slv_agent  = apb_slv_agent::type_id::create("slv_agent", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    sys_agent.mon.ap_in.connect(scoreboard.exp_imp);     // Expected from system monitor
    slv_agent.mon.ap_out.connect(scoreboard.act_imp);    // Actual from slave monitor
  endfunction

endclass
