// ============================================================================
// FILE: tb_top.sv
// DESCRIPTION:
//   This is the TOP-LEVEL MODULE of the entire testbench.
//   It is NOT a UVM class — it's a regular SystemVerilog module.
//
//   It is responsible for:
//     1. Generating the clock (PCLK)
//     2. Generating the reset (PRESETn)
//     3. Instantiating the APB Interface
//     4. Instantiating the DUT (slave1) and connecting it to the interface
//     5. Storing the interface in uvm_config_db so UVM components can find it
//     6. Starting the UVM test
//
//   EXECUTION FLOW:
//   ---------------
//   1. Simulator starts → tb_top runs
//   2. Clock starts toggling
//   3. Reset is applied for 5 clock cycles
//   4. run_test() looks for +UVM_TESTNAME on the command line
//   5. UVM creates the test → env → agent → driver/monitor/sequencer
//   6. Sequences drive the DUT through the interface
//   7. Monitor watches and sends transactions to the Scoreboard
//   8. Scoreboard reports PASS/FAIL
// ============================================================================

`timescale 1ns/1ns

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_pkg::*;

  // ---- Clock and Reset ----
  reg PCLK;
  reg PRESETn;

  // ---- Clock Generation: 10ns period (100 MHz) ----
  initial PCLK = 0;
  always #5 PCLK = ~PCLK;   // Toggle every 5ns → 10ns period

  // ---- Reset Generation ----
  initial begin
    PRESETn = 0;       // Assert reset (active low)
    #50;               // Hold reset for 50ns (5 clock cycles)
    PRESETn = 1;       // Release reset
    `uvm_info("TB_TOP", "Reset released", UVM_LOW)
  end

  // ---- Instantiate the APB Interface ----
  apb_if apb_vif(.PCLK(PCLK), .PRESETn(PRESETn));

  // ---- Instantiate the DUT (slave1) ----
  // Connect the DUT ports to the interface signals
  slave1 dut (
    .PCLK     (PCLK),
    .PRESETn  (PRESETn),
    .PSEL     (apb_vif.PSEL),
    .PENABLE  (apb_vif.PENABLE),
    .PWRITE   (apb_vif.PWRITE),
    .PADDR    (apb_vif.PADDR),
    .PWDATA   (apb_vif.PWDATA),
    .PRDATA1  (apb_vif.PRDATA1),
    .PREADY   (apb_vif.PREADY)
  );

  // ---- Store Interface in Config DB and Start Test ----
  initial begin
    // Store the interface handle so all UVM components can access it.
    // Key: "vif" — this must match the key used in driver/monitor's get().
    uvm_config_db #(virtual apb_if)::set(null, "*", "vif", apb_vif);

    // Optional: Enable waveform dumping for debugging
    $dumpfile("apb_slave_tb.vcd");
    $dumpvars(0, tb_top);

    // Start the UVM test!
    // The test name is specified on the command line: +UVM_TESTNAME=apb_test
    run_test();
  end

endmodule
