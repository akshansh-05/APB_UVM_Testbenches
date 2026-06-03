// ============================================================================
// FILE: apb_master_test.sv
// DESCRIPTION:
//   UVM Test for the APB Master Bridge.
//   Creates the environment and runs the write sequence that sends
//   transactions to Slave 1.
// ============================================================================

class apb_master_test extends uvm_test;

  `uvm_component_utils(apb_master_test)

  // ---- The Environment ----
  apb_master_env env;

  // ---- Constructor ----
  function new(string name = "apb_master_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_master_env::type_id::create("env", this);
  endfunction

  // ---- Run Phase ----
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Starting", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    // Wait for reset to complete (reset applied by tb_top)
    #100;

    begin
      // Run the write sequence (writes 5 transactions to Slave 1)
      apb_master_write_seq seq;
      seq = apb_master_write_seq::type_id::create("seq");
      seq.start(env.agent.sqr);
    end

    #100;

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Complete", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass
