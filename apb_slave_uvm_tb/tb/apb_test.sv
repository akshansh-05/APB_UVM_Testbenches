// ============================================================================
// FILE: apb_test.sv
// DESCRIPTION:
//   The Test class is the TOP of the UVM class hierarchy.
//
//   It is responsible for:
//     1. Creating the Environment (which creates everything else).
//     2. Choosing WHICH sequence to run.
//     3. Controlling the simulation start and end.
//
//   UVM PHASES:
//   -----------
//   build_phase   → Create components (env, agents, etc.)
//   connect_phase → Wire components together (done automatically by sub-components)
//   run_phase     → Start stimulus (sequences) and wait for them to finish
//   report_phase  → Print summary (done automatically by scoreboard)
// ============================================================================

class apb_test extends uvm_test;

  `uvm_component_utils(apb_test)

  // ---- The Environment ----
  apb_env env;

  // ---- Constructor ----
  function new(string name = "apb_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase: Create the environment ----
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

  // ---- Run Phase: Launch the test sequence ----
  task run_phase(uvm_phase phase);

    // raise_objection: Tells UVM "don't end the test yet, I'm still working"
    phase.raise_objection(this);

    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "  APB Slave UVM Test Starting", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)

    // Wait for reset to complete (reset is applied by tb_top.sv)
    #100;

    begin
      // Create and start the write-then-read sequence
      apb_write_read_seq seq;
      seq = apb_write_read_seq::type_id::create("seq");
      seq.start(env.agent.sqr);  // Run the sequence on the agent's sequencer
    end

    // Small delay after sequence completes, then end the test
    #100;

    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "  APB Slave UVM Test Complete", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)

    // drop_objection: Tells UVM "I'm done, you can end the simulation"
    phase.drop_objection(this);
  endtask

endclass
