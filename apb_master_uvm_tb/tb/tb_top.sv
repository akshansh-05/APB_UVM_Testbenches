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
  // "import apb_master_pkg::*" brings in all our UVM classes
  // (test, env, agent, driver, monitor, scoreboard, seq_item, sequences).
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_master_pkg::*;

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
  apb_master_if apb_vif(.PCLK(PCLK), .PRESETn(PRESETn));

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
  //    For read transactions, the slave returns data based on the address.
  //    XOR with 0xA5 creates a predictable, non-trivial pattern:
  //      addr=0x00 → PRDATA=0xA5
  //      addr=0x10 → PRDATA=0xB5
  //      addr=0xFF → PRDATA=0x5A
  //    The scoreboard knows this formula and checks apb_read_data_out
  //    against it to verify the master correctly passes read data through.
  assign apb_vif.PREADY = apb_vif.PENABLE;
  assign apb_vif.PRDATA = apb_vif.PADDR[7:0] ^ 8'hA5;

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
  initial begin

    // Store the virtual interface handle in UVM's config_db.
    // This is how UVM classes get access to the interface signals:
    //   - "null" → accessible from any component in the hierarchy
    //   - "*"    → matches all components (wildcard)
    //   - "vif"  → the key name (must match what driver/monitor use in ::get)
    //   - apb_vif → the actual interface instance handle
    uvm_config_db #(virtual apb_master_if)::set(null, "*", "vif", apb_vif);

    // Enable VCD waveform dumping for debugging.
    // $dumpfile sets the output filename.
    // $dumpvars(0, tb_top) dumps ALL signals in tb_top and below, recursively.
    // NOTE: Requires "-access +rwc" in the xrun command for Xcelium.
    $dumpfile("apb_master_tb.vcd");
    $dumpvars(0, tb_top);

    // Start the UVM test.
    // run_test() reads +UVM_TESTNAME from the command line (e.g., "apb_master_test"),
    // creates that test class via the factory, and executes all UVM phases:
    //   build → connect → run → extract → check → report → final
    run_test();
  end

endmodule
