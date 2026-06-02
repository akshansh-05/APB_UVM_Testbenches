// ============================================================================
// FILE: tb_top.sv
// DESCRIPTION:
//   Top-level testbench module for the APB Master Bridge.
//
//   KEY DIFFERENCE FROM SLAVE TB:
//   This tb_top includes a SLAVE RESPONDER — a simple block that emulates
//   the APB slave's response to the master. Without it, the master would
//   never see PREADY=1 and would be stuck in the ENABLE state forever.
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

`timescale 1ns/1ns

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_master_pkg::*;

  // ---- Clock and Reset ----
  reg PCLK;
  reg PRESETn;

  // ---- Clock Generation: 10ns period (100 MHz) ----
  initial PCLK = 0;
  always #5 PCLK = ~PCLK;

  // ---- Reset Generation ----
  initial begin
    PRESETn = 0;       // Assert reset (active low)
    #50;               // Hold for 50ns (5 clock cycles)
    PRESETn = 1;       // Release reset
    `uvm_info("TB_TOP", "Reset released", UVM_LOW)
  end

  // ---- Instantiate the APB Master Interface ----
  apb_master_if apb_vif(.PCLK(PCLK), .PRESETn(PRESETn));

  // ============================================================
  //  SLAVE RESPONDER
  //  This emulates a simple APB slave that always responds
  //  immediately (zero wait-state).
  //
  //  PREADY: Goes high whenever PENABLE is high.
  //          This tells the master "I'm ready, complete the transfer."
  //
  //  PRDATA: Returns a predictable pattern based on the address.
  //          The scoreboard uses this pattern to verify read data.
  //          Pattern: PADDR[7:0] XOR 0xA5
  //          Example: addr=0x10 → PRDATA = 0x10 ^ 0xA5 = 0xB5
  // ============================================================
  assign apb_vif.PREADY = apb_vif.PENABLE;
  assign apb_vif.PRDATA = apb_vif.PADDR[7:0] ^ 8'hA5;

  // ---- Instantiate the DUT (master_bridge) ----
  master_bridge dut (
    .PCLK              (PCLK),
    .PRESETn            (PRESETn),
    // System-side inputs (driven by UVM driver via interface)
    .apb_write_paddr    (apb_vif.apb_write_paddr),
    .apb_read_paddr     (apb_vif.apb_read_paddr),
    .apb_write_data     (apb_vif.apb_write_data),
    .READ_WRITE         (apb_vif.READ_WRITE),
    .transfer           (apb_vif.transfer),
    // Slave response inputs (driven by slave responder)
    .PRDATA             (apb_vif.PRDATA),
    .PREADY             (apb_vif.PREADY),
    // APB bus outputs (monitored by UVM monitor)
    .PSEL1              (apb_vif.PSEL1),
    .PSEL2              (apb_vif.PSEL2),
    .PENABLE            (apb_vif.PENABLE),
    .PADDR              (apb_vif.PADDR),
    .PWRITE             (apb_vif.PWRITE),
    .PWDATA             (apb_vif.PWDATA),
    .apb_read_data_out  (apb_vif.apb_read_data_out),
    .PSLVERR            (apb_vif.PSLVERR)
  );

  // ---- Store Interface in Config DB and Start Test ----
  initial begin
    // Store interface handle for UVM components
    uvm_config_db #(virtual apb_master_if)::set(null, "*", "vif", apb_vif);

    // Waveform dumping
    $dumpfile("apb_master_tb.vcd");
    $dumpvars(0, tb_top);

    // Start UVM test (test name from +UVM_TESTNAME command line arg)
    run_test();
  end

endmodule
