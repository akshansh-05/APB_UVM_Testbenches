// ============================================================================
// FILE: tb_top.sv
// DESCRIPTION:
//   Top-level testbench module for the APB Master Bridge.
//
//   This is the ONLY module in the testbench (everything else is classes).
//   It connects the UVM world (classes) to the RTL world (modules) via
//   the virtual interface.
//
//   RESPONSIBILITIES:
//     1. Generate clock and reset
//     2. Instantiate the interface
//     3. Instantiate the DUT and connect it to the interface
//     4. Provide a slave responder (since there's no real slave)
//     5. Store the interface handle in config_db for UVM components
//     6. Start the UVM test
//
//   KEY DIFFERENCE FROM SLAVE TB:
//   This tb_top includes a SLAVE RESPONDER — a simple block that emulates
//   the APB slave's response. Without it, the master would never see
//   PREADY=1 and would be stuck in the ENABLE state forever.
//
//   SLAVE RESPONDER BEHAVIOR:
//     - PREADY mirrors PENABLE (zero wait-state slave)
//     - PRDATA = PADDR[7:0] XOR 0xA5 (predictable pattern for verification)
//
//   EXECUTION FLOW:
//   1. Clock starts, reset applied for 50ns
//   2. UVM test starts, driver drives system-side inputs
//   3. DUT processes FSM: IDLE → SETUP → ENABLE
//   4. Slave responder sees PENABLE=1, drives PREADY=1
//   5. DUT completes transfer, monitor captures, scoreboard checks
// ============================================================================

// Set the simulation time unit and precision.
// 1ns/1ns means: time unit = 1ns, time precision = 1ns
// All #delays in this module use nanosecond resolution.
`timescale 1ns/1ns

module tb_top;

  // Import UVM base library and our testbench package.
  // "import uvm_pkg::*" brings in run_test(), uvm_config_db, etc.
  // "import apb_pkg::*" brings in all our UVM classes
  // (test, env, agent, driver, monitor, scoreboard, seq_item, sequences).
  import uvm_pkg::*; // Imports standard UVM package scope to get run_test, etc.
  `include "uvm_macros.svh" // Includes standard UVM preprocessor macro compiler definitions
  import apb_pkg::*; // Imports our newly refactored TB package containing all classes

  // ---- Clock and Reset ----
  // "reg" is used because these are driven by procedural blocks (initial/always).
  reg PCLK;      // APB clock (100 MHz = 10ns period)
  reg PRESETn;   // Active-low reset (0 = reset active, 1 = normal operation)

  // ---- Clock Generation: 10ns period (100 MHz) ----
  // Toggle PCLK every 5ns → full period = 10ns.
  // The initial block sets the starting value, then the always block toggles.
  initial PCLK = 0;
  always #5 PCLK = ~PCLK;

  // ---- Reset Generation ----
  // Apply reset for 50ns (5 clock cycles), then release.
  // The DUT uses PRESETn (active-low), so:
  //   PRESETn=0 → DUT is in reset, FSM goes to IDLE
  //   PRESETn=1 → DUT operates normally
  initial begin
    PRESETn = 0;       // Assert reset (active low)
    #50;               // Hold for 50ns (5 clock cycles)
    PRESETn = 1;       // Release reset
    `uvm_info("TB_TOP", "Reset released", UVM_LOW)
  end

  // ---- Instantiate the APB Master Interface ----
  // The interface bundles all APB signals in one place.
  // We pass clock and reset as port connections.
  // "apb_vif" is the instance name — this handle is stored in config_db
  // so UVM components (driver, monitor) can access the signals.
  apb_if apb_vif(.PCLK(PCLK), .PRESETn(PRESETn)); // Instantiates our new refactored apb_if interface with default widths

  // ============================================================
  //  SLAVE RESPONDER
  // ============================================================
  // Since we're testing the MASTER, we need something to act as
  // the SLAVE on the other end of the APB bus.
  //
  // These two assign statements emulate a simple zero-wait-state slave:
  //
  //  PREADY = PENABLE:
  //    In APB, the slave asserts PREADY to signal "I'm ready to complete
  //    the transfer." By tying PREADY to PENABLE, the slave responds
  //    immediately in the same cycle that PENABLE goes high.
  //    This means zero wait states (fastest possible slave).
  //
  //  PRDATA = PADDR[7:0] ^ 8'hA5:
  //    XOR with 0xA5 creates a predictable, non-trivial pattern:
  //      addr=0x00 → PRDATA=0xA5
  //      addr=0x10 → PRDATA=0xB5
  //      addr=0xFF → PRDATA=0x5A
  //  // The slave response signals (PREADY, PRDATA) are driven dynamically
  //  // by the UVM Slave Driver (apb_slave_driver) through the virtual interface.

  // ---- Instantiate the DUT (master_bridge) ----
  // Connect the DUT's ports to the interface signals.
  // The DUT reads system-side signals (driven by driver via interface)
  // and drives APB-side signals (observed by monitor via interface).
  master_bridge dut (
    .PCLK              (PCLK),
    .PRESETn            (PRESETn),

    // System-side inputs (driven by UVM driver via interface)
    .apb_write_paddr    (apb_vif.apb_write_paddr),   // Write address from system
    .apb_read_paddr     (apb_vif.apb_read_paddr),    // Read address from system
    .apb_write_data     (apb_vif.apb_write_data),     // Write data from system
    .READ_WRITE         (apb_vif.READ_WRITE),          // Read/write direction
    .transfer           (apb_vif.transfer),            // Transfer request

    // Slave response inputs (driven by slave responder above)
    .PRDATA             (apb_vif.PRDATA),              // Read data from slave
    .PREADY             (apb_vif.PREADY),              // Slave ready signal

    // APB bus outputs (monitored by UVM monitor via interface)
    .PSEL1              (apb_vif.PSEL1),               // Slave 1 select
    .PSEL2              (apb_vif.PSEL2),               // Slave 2 select
    .PENABLE            (apb_vif.PENABLE),             // APB enable
    .PADDR              (apb_vif.PADDR),               // APB address
    .PWRITE             (apb_vif.PWRITE),              // APB write/read
    .PWDATA             (apb_vif.PWDATA),              // APB write data
    .apb_read_data_out  (apb_vif.apb_read_data_out),  // Read data to system
    .PSLVERR            (apb_vif.PSLVERR)              // Slave error
  );

  // ---- Store Interface in Config DB and Start Test ----
  initial begin // Fix: Starts the missing initial block execution thread for test control
    // =========================================================================
    // THE HARDWARE-SOFTWARE BRIDGE: uvm_config_db#(T)::set
    // =========================================================================
    // The class-based UVM environment is dynamic (objects are created and
    // destroyed on the fly), whereas the HDL design is static. To connect the
    // two, we use UVM's Configuration Database (uvm_config_db).
    //
    // uvm_config_db#(virtual apb_if)::set(...) stores the handle to our
    // physical interface instance (apb_vif) inside the database.
    //
    // Parameters Explained:
    //   1. cntxt (context): uvm_component parent context.
    //      - We pass `null` here because this initial block runs inside a static
    //        Verilog module (`tb_top`), which is NOT a UVM component class.
    //        Passing `null` makes this entry global or anchored to the root.
    //   2. inst_name (instance name): Path string to target components.
    //      - We pass `"*"` (wildcard) which means *all* components in the testbench
    //        hierarchy will have permission to read this entry. If we wanted to
    //        restrict it, we could pass `"uvm_test_top.env.agent.drv"`.
    //   3. field_name: String lookup key.
    //      - We pass `"vif"`. Any component attempting to retrieve this interface
    //        must query the database with this exact string name.
    //   4. value: The actual data or handle being stored.
    //      - We pass `apb_vif`, which is the physical interface instance.
    // =========================================================================
    uvm_config_db #(virtual apb_if)::set(null, "*", "vif", apb_vif); // Registers interface in database as type virtual apb_if

    // Enable VCD waveform dumping for debugging.
    // $dumpfile sets the output filename.
    // $dumpvars(0, tb_top) dumps ALL signals in tb_top and below, recursively.
    // NOTE: Requires "-access +rwc" in the xrun command for Xcelium.
    $dumpfile("apb_master_tb.vcd"); // Creates waveform dumping output database file
    $dumpvars(0, tb_top); // Tells simulator to dump all signals inside tb_top scope

    // =========================================================================
    // STARTING THE UVM ENGINE: run_test()
    // =========================================================================
    // run_test() is a global UVM task that does the following:
    //   1. Checks for the "+UVM_TESTNAME=<name>" argument on the simulator's
    //      command line (e.g. +UVM_TESTNAME=apb_master_test).
    //   2. Queries the UVM Factory to instantiate the test class matching that name.
    //   3. Starts the execution of UVM Phases in order:
    //      - TOP-DOWN: build_phase (instantiate components)
    //      - BOTTOM-UP: connect_phase (wire TLM ports)
    //      - BOTTOM-UP: end_of_elaboration_phase
    //      - PARALLEL: run_phase (time-consuming simulation tasks)
    //      - BOTTOM-UP: extract_phase, check_phase, report_phase, final_phase
    // =========================================================================
    run_test(); // Invokes the global UVM test executor
  end // End of initial begin block

endmodule
