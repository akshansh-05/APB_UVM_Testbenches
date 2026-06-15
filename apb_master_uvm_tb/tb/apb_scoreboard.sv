`include "uvm_macros.svh"
import uvm_pkg::*;

`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class apb_scoreboard extends uvm_scoreboard;
  
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp_expected #(apb_seq_item, apb_scoreboard) exp_port;
  uvm_analysis_imp_actual   #(apb_seq_item, apb_scoreboard) act_port;

  function new(string name = "apb_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    exp_port = new("exp_port", this);
    act_port = new("act_port", this);
  endfunction

  virtual function void write_expected(apb_seq_item item);
    `uvm_info("SCOREBOARD", $sformatf("Received EXPECTED Transaction:\n%s", item.sprint()), UVM_LOW)
  endfunction

  virtual function void write_actual(apb_seq_item item);
    `uvm_info("SCOREBOARD", $sformatf("Received ACTUAL Transaction:\n%s", item.sprint()), UVM_LOW)
  endfunction

endclass
