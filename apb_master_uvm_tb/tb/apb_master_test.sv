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

  // =========================================================================
  // UVM RUN PHASE: Stimulus Application & Simulation Control
  // =========================================================================
  // The run_phase task is where the test executes.
  //
  // THE UVM OBJECTION MECHANISM:
  //   In UVM, simulation is time-consuming only if there are active "objections".
  //   If no objections are raised, the simulation terminates at time 0.
  //
  //   - `phase.raise_objection(this)`: Registers a request to keep the simulation
  //     running. It acts as a "keep alive" vote.
  //   - `phase.drop_objection(this)`: Relinquishes the request. When the count
  //     of all active objections across the entire testbench drops to zero,
  //     UVM automatically ends the `run_phase` and stops simulation time.
  //
  //   - Best Practice: Always raise and drop objections at the highest level
  //     (inside the Test or inside the Top Sequences). Avoid raising/dropping
  //     them in low-level drivers or monitors, as they should be reactive.
  // =========================================================================
  task run_phase(uvm_phase phase);

    // Raise objection to start simulation and prevent early termination.
    phase.raise_objection(this);

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Starting", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    // Wait for reset to complete.
    // tb_top applies reset for 50ns. We wait 100ns to be safe and
    // ensure the DUT is fully out of reset before sending transactions.
    #100;

    // ─────────────────────────────────────────────────────────────────────────
    // SEQUENCE INSTANTIATION & EXECUTION
    // ─────────────────────────────────────────────────────────────────────────
    // We instantiate the sequence using the UVM factory, then run it.
    // `seq.start(...)` is a blocking call:
    //   1. It registers the sequence on the agent's sequencer (`env.agent.sqr`).
    //   2. It executes the sequence's `body()` task.
    //   3. It suspends execution of this run_phase task until `body()` completes.
    // ─────────────────────────────────────────────────────────────────────────
    begin
      apb_master_write_read_seq seq;
      seq = apb_master_write_read_seq::type_id::create("seq");
      seq.start(env.agent.sqr);   // Run sequence on the agent's sequencer
    end

    // Wait a brief period after sequence completion for any final bus cycles,
    // monitor sampling, or scoreboard checks to settle.
    #100;

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Complete", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    // Drop objection: we are done generating stimulus.
    // If no other objections are active, UVM will shut down the run_phase.
    phase.drop_objection(this);
  endtask

endclass
