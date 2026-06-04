// ============================================================================
// FILE: apb_master_test.sv
// DESCRIPTION:
//   UVM Test for the APB Master Bridge.
//
//   The test is the TOP of the UVM hierarchy. It:
//     1. Creates the environment (which creates agent + scoreboard)
//     2. Runs sequences to exercise the DUT
//     3. Controls simulation start and end via objections
//
//   UVM TEST LIFECYCLE:
//     build_phase  → create env (and its children recursively)
//     connect_phase → wire up TLM ports
//     run_phase    → execute sequences (the actual simulation)
//     report_phase → print results (handled by scoreboard)
//
//   OBJECTION MECHANISM:
//     raise_objection() → tells UVM "simulation should keep running"
//     drop_objection()  → tells UVM "I'm done, you can end simulation"
//     UVM automatically ends simulation when ALL objections are dropped.
// ============================================================================

// Extends uvm_test, the base class for all UVM tests.
// The test name is specified on the command line: +UVM_TESTNAME=apb_master_test
// UVM uses the factory to create the test by name.
class apb_master_test extends uvm_test;

  // Register with UVM factory so it can be created via +UVM_TESTNAME
  `uvm_component_utils(apb_master_test)

  // ---- The Environment ----
  // Handle to the env, which contains all verification components.
  apb_master_env env;

  // ---- Constructor ----
  function new(string name = "apb_master_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build Phase ----
  // Create the environment. This triggers a cascade of build_phase calls:
  //   test.build → env.build → agent.build → driver.build, monitor.build, etc.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_master_env::type_id::create("env", this);
  endfunction

  // ---- Run Phase ----
  // This is where the actual test stimulus is applied.
  // It runs as a task (has simulation time) concurrently with
  // all other run_phase tasks (driver, monitor, etc.)
  task run_phase(uvm_phase phase);

    // Raise objection: prevent UVM from ending the simulation.
    // Without this, UVM would end immediately because no one
    // is requesting simulation time.
    phase.raise_objection(this);

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Starting", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    // Wait for reset to complete.
    // tb_top applies reset for 50ns. We wait 100ns to be safe and
    // ensure the DUT is fully out of reset before sending transactions.
    #100;

    // ── Run the write sequence ──
    // Create the sequence, then start it on the agent's sequencer.
    // seq.start() BLOCKS until the sequence's body() task completes
    // (i.e., all 5 write transactions have been driven and completed).
    begin
      apb_master_write_seq seq;
      seq = apb_master_write_seq::type_id::create("seq");
      seq.start(env.agent.sqr);   // Run sequence on the agent's sequencer
    end

    // Wait a bit after the last transaction for any final
    // monitoring/scoring to complete.
    #100;

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Complete", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    // Drop objection: tell UVM we're done.
    // UVM will now proceed to the extract, check, and report phases.
    phase.drop_objection(this);
  endtask

endclass
