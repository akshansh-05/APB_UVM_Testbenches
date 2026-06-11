// =============================================================================
// FILE: apb_test.sv
// DESCRIPTION:
//   APB Test Classes — configure the verification environment and trigger
//   stimulus execution.
//
//   This file contains TWO classes:
//
//   1. test_apb_base (BASE TEST):
//      The foundation test class that all concrete tests extend.
//      It instantiates the apb_env environment during build_phase.
//      Contains no run_phase — it just sets up the hierarchy.
//
//   2. apb_master_test (CONCRETE WRITE-READ TEST):
//      Extends the base test to run the write-then-read-back sequence.
//      This is the test specified via +UVM_TESTNAME=apb_master_test on
//      the simulator command line.
//
//   UVM TEST EXECUTION FLOW:
//     1. tb_top calls run_test()
//     2. UVM factory creates the test specified by +UVM_TESTNAME
//     3. build_phase: test creates env → env creates agents, monitors, scoreboard
//     4. connect_phase: TLM ports are wired (sys_mon→scoreboard, bus_mon→scoreboard)
//     5. run_phase: test raises objection, runs sequence, drops objection
//     6. report_phase: scoreboard prints PASS/FAIL summary
//
//   UVM OBJECTION MECHANISM:
//     phase.raise_objection() prevents the simulation from ending prematurely.
//     The simulation keeps running as long as any objection is raised.
//     phase.drop_objection() signals that this test's stimulus is complete.
//     After all objections are dropped, UVM proceeds to the report phase.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// =============================================================================
// BASE TEST CLASS
// Provides the common environment instantiation shared by all concrete tests.
// =============================================================================
class test_apb_base extends uvm_test;

  `uvm_component_utils(test_apb_base)    // Register with UVM factory

  apb_env env;    // The verification environment containing all agents and scoreboard

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "test_apb_base", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // BUILD PHASE — create the verification environment
  // The env in turn creates sys_agent, slv_agent, monitor, and scoreboard.
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

endclass

// =============================================================================
// CONCRETE TEST: apb_master_test
// Runs a single write-then-read-back sequence to verify basic APB write
// transfer functionality and data integrity through the master bridge DUT.
//
// HOW TO RUN:
//   vsim ... +UVM_TESTNAME=apb_master_test
//   (or xrun ... +UVM_TESTNAME=apb_master_test)
// =============================================================================
class apb_master_test extends test_apb_base;

  `uvm_component_utils(apb_master_test)    // Register with UVM factory

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR
  // ---------------------------------------------------------------------------
  function new(string name = "apb_master_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // RUN PHASE — execute the test stimulus
  //
  // Steps:
  //   1. Raise objection — keep simulation alive until our sequence completes
  //   2. Wait 100ns — allow reset to propagate and DUT to stabilize
  //   3. Create and start the write-read sequence on the system agent's sequencer
  //   4. Wait 100ns — allow any final transactions to propagate
  //   5. Drop objection — signal that stimulus is complete, allow UVM to proceed
  //      to check_phase and report_phase for final scoreboard summary
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    apb_write_read_seq seq;

    // Keep simulation alive while our test runs
    phase.raise_objection(this);

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Starting", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    // Wait for reset to fully propagate (reset deasserts at 50ns in tb_top)
    #100ns;

    // Create the write-read sequence and start it on the system agent's sequencer
    // The sequence will:
    //   1. Generate a write transaction with random addr/data
    //   2. Drive it through the system agent → DUT → slave (stores data)
    //   3. Generate a read transaction to the same address
    //   4. Drive it through the system agent → DUT → slave (returns data)
    //   5. Scoreboard verifies both transactions automatically
    seq = apb_write_read_seq::type_id::create("seq");
    seq.start(env.sys_agent.sqr);    // Blocking: returns after sequence completes

    // Post-sequence settling time
    #100ns;

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Complete", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    // Allow simulation to end — UVM will proceed to report_phase
    phase.drop_objection(this);
  endtask

endclass
