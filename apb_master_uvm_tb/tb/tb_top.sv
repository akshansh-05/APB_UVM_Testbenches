// =============================================================================
// FILE: tb_top.sv
// DESCRIPTION:
//   Top-Level Testbench Module — the ONLY module in the testbench (everything
//   else is UVM classes). This module bridges the static RTL world (modules,
//   wires, registers) and the dynamic UVM world (classes, objects, transactions).
//
//   RESPONSIBILITIES:
//     1. CLOCK GENERATION: 100 MHz clock (10ns period, 5ns half-period)
//     2. RESET GENERATION: Active-low reset, asserted for 50ns, then released
//     3. INTERFACE INSTANTIATION: Creates the apb_if virtual interface
//     4. DUT INSTANTIATION: Creates the master_bridge DUT and connects its
//        ports to the virtual interface signals
//     5. CONFIG_DB REGISTRATION: Stores the virtual interface handle so all
//        UVM components can retrieve it during their build_phase
//     6. VCD WAVEFORM DUMPING: Enables signal waveform capture for debugging
//     7. UVM ENGINE LAUNCH: Calls run_test() to start the UVM phase machine
//
//   DUT CONNECTIONS:
//     The master_bridge DUT has three groups of ports:
//       a. System inputs  — connected to apb_vif signals driven by sys_agent
//       b. Slave inputs   — connected to apb_vif signals driven by slv_agent
//       c. Bus outputs    — connected to apb_vif signals sampled by monitors
//
//   CONFIG_DB:
//     uvm_config_db #(virtual apb_if)::set(null, "*", "vif", apb_vif)
//     This makes the virtual interface globally accessible (null context, "*"
//     wildcard path) so that every UVM component (drivers, monitors) can
//     retrieve it using: uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif)
//
//   TEST SELECTION:
//     The test to run is specified on the simulator command line via:
//       +UVM_TESTNAME=apb_master_test
//     run_test() reads this plusarg and creates the corresponding test class.
// =============================================================================

`timescale 1ns/1ns    // Time unit = 1ns, time precision = 1ns

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_pkg::*;

  // ---------------------------------------------------------------------------
  // CLOCK AND RESET GENERATION
  // ---------------------------------------------------------------------------
  reg PCLK;       // APB clock signal — 100 MHz (10ns period)
  reg PRESETn;    // Active-low reset — 0=reset active, 1=normal operation

  // Toggle PCLK every 5ns → full period = 10ns → 100 MHz
  initial PCLK = 0;
  always #5 PCLK = ~PCLK;

  // Reset sequence: assert for 50ns (5 clock cycles), then release
  // The DUT FSM goes to IDLE during reset, then starts normal operation
  initial begin
    PRESETn = 0;        // Assert reset (active low)
    #50;                // Hold reset for 50ns
    PRESETn = 1;        // Release reset — DUT begins normal operation
    `uvm_info("TB_TOP", "Reset released", UVM_LOW)
  end

  // ---------------------------------------------------------------------------
  // VIRTUAL INTERFACE INSTANTIATION
  // The apb_if bundles all signals and provides clocking blocks + modports.
  // Clock and reset are passed as port connections to the interface.
  // ---------------------------------------------------------------------------
  apb_if apb_vif(.PCLK(PCLK), .PRESETn(PRESETn));

  // ---------------------------------------------------------------------------
  // DUT INSTANTIATION — APB Master Bridge
  // The master_bridge is the Design Under Test (DUT). Its ports are connected
  // to the virtual interface signals, which are driven/sampled by UVM agents.
  //
  // Port mapping by group:
  //   System inputs  → driven by apb_sys_driver via master_cb clocking block
  //   Slave inputs   → driven by apb_slv_driver via slave_cb clocking block
  //   Bus outputs    → sampled by apb_monitor via monitor_cb clocking block
  // ---------------------------------------------------------------------------
  master_bridge dut (
    // Clock and reset
    .PCLK              (PCLK),
    .PRESETn            (PRESETn),

    // System-side inputs (driven by sys_agent)
    .apb_write_paddr    (apb_vif.apb_write_paddr),   // Write target address from system
    .apb_read_paddr     (apb_vif.apb_read_paddr),    // Read target address from system
    .apb_write_data     (apb_vif.apb_write_data),     // Write data payload from system
    .READ_WRITE         (apb_vif.READ_WRITE),          // Direction: 0=write, 1=read
    .transfer           (apb_vif.transfer),            // Transfer request strobe

    // Slave response inputs (driven by slv_agent)
    .PRDATA             (apb_vif.PRDATA),              // Read data from slave
    .PREADY             (apb_vif.PREADY),              // Slave ready signal

    // APB bus outputs (sampled by monitors)
    .PSEL1              (apb_vif.PSEL1),               // Slave 1 chip select
    .PSEL2              (apb_vif.PSEL2),               // Slave 2 chip select
    .PENABLE            (apb_vif.PENABLE),             // APB enable (ACCESS phase)
    .PADDR              (apb_vif.PADDR),               // APB address bus
    .PWRITE             (apb_vif.PWRITE),              // APB direction (1=write)
    .PWDATA             (apb_vif.PWDATA),              // APB write data bus
    .apb_read_data_out  (apb_vif.apb_read_data_out),  // Read data returned to system
    .PSLVERR            (apb_vif.PSLVERR)              // Slave error flag
  );

  // ---------------------------------------------------------------------------
  // UVM CONFIGURATION AND LAUNCH
  // ---------------------------------------------------------------------------
  initial begin
    // Register the virtual interface in the UVM configuration database.
    // Parameters:
    //   null  — global context (accessible from anywhere in the hierarchy)
    //   "*"   — wildcard instance path (all components can read this entry)
    //   "vif" — lookup key (must match what components use in their get() calls)
    //   apb_vif — the actual virtual interface handle being stored
    uvm_config_db #(virtual apb_if)::set(null, "*", "vif", apb_vif);

    // Enable VCD waveform dumping for debugging
    // The dump file captures all signals in tb_top and below for waveform viewing
    // NOTE: Requires "-access +rwc" flag when using Cadence Xcelium
    $dumpfile("apb_master_tb.vcd");
    $dumpvars(0, tb_top);

    // Launch the UVM test engine.
    // run_test() performs:
    //   1. Reads +UVM_TESTNAME from the command line to select the test class
    //   2. Creates the test via the UVM factory
    //   3. Executes the UVM phase machine:
    //      BUILD → CONNECT → END_OF_ELABORATION → START_OF_SIMULATION
    //      → RUN (parallel, time-consuming) → EXTRACT → CHECK → REPORT → FINAL
    //   4. Calls $finish when all phases complete
    run_test();
  end

endmodule
