`include "uvm_macros.svh"
import uvm_pkg::*;

// Base test — creates the environment
class test_apb_base extends uvm_test;

  `uvm_component_utils(test_apb_base)

  apb_env env;

  function new(string name = "test_apb_base", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info("TEST", "============ UVM COMPONENT TOPOLOGY ============", UVM_LOW)
    uvm_top.print_topology();
  endfunction

endclass

// Concrete test — runs write-then-read-back sequence
class apb_master_test extends test_apb_base;

  `uvm_component_utils(apb_master_test)

  function new(string name = "apb_master_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_write_read_seq seq;

    phase.raise_objection(this);

    `uvm_info("TEST", "======== APB Master Bridge Test Starting ========", UVM_LOW)

    #100ns;  // Wait for reset to propagate

    seq = apb_write_read_seq::type_id::create("seq");
    seq.start(env.sys_agent.sqr);

    #100ns;  // Post-sequence settling

    `uvm_info("TEST", "======== APB Master Bridge Test Complete ========", UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass
