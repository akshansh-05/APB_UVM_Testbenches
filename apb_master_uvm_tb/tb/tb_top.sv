//   Top-level testbench // The top-level testbench module generates clock and reset, instantiates
// the physical interfaces, wires the DUT, and triggers the UVM run phase.
module for the APB Master Bridge.
//   This is the ONLY module in the testbench (everything else is classes).
//   It connects the UVM world (classes) to the RTL world (modules) via
//     4. Provide a slave responder (since there's no real slave)
//   KEY DIFFERENCE FROM SLAVE TB:
//   the APB slave's response. Without it, the master would never see
//     - PRDATA = PADDR[7:0] XOR 0xA5 (predictable pattern for verification)
//   4. Slave responder sees PENABLE=1, drives PREADY=1

// 1ns/1ns means: time unit = 1ns, time precision = 1ns
// All #delays in this module use nanosecond resolution.
`timescale 1ns/1ns

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_pkg::*;

  reg PCLK;      // APB clock (100 MHz = 10ns period)
  reg PRESETn;   // Active-low reset (0 = reset active, 1 = normal operation)

  // Toggle PCLK every 5ns → full period = 10ns.
  initial PCLK = 0;
  always #5 PCLK = ~PCLK;

  // The DUT uses PRESETn (active-low), so:
  //   PRESETn=0 → DUT is in reset, FSM goes to IDLE
  //   PRESETn=1 → DUT operates normally
  initial begin
    PRESETn = 0;       // Assert reset (active low)
    #50;
    PRESETn = 1;
    `uvm_info("TB_TOP", "Reset released", UVM_LOW)
  end

  // We pass clock and reset as port connections.
  apb_if apb_vif(.PCLK(PCLK), .PRESETn(PRESETn));

  // Since we're testing the MASTER, we need something to act as
  //    immediately in the same cycle that PENABLE goes high.
  //    This means zero wait states (fastest possible slave).
  //  PRDATA = PADDR[7:0] ^ 8'hA5:

  master_bridge dut (
    .PCLK              (PCLK),
    .PRESETn            (PRESETn),

    .apb_write_paddr    (apb_vif.apb_write_paddr),   // Write address from system
    .apb_read_paddr     (apb_vif.apb_read_paddr),    // Read address from system
    .apb_write_data     (apb_vif.apb_write_data),     // Write data from system
    .READ_WRITE         (apb_vif.READ_WRITE),
    .transfer           (apb_vif.transfer),

    .PRDATA             (apb_vif.PRDATA),              // Read data from slave
    .PREADY             (apb_vif.PREADY),

    .PSEL1              (apb_vif.PSEL1),
    .PSEL2              (apb_vif.PSEL2),
    .PENABLE            (apb_vif.PENABLE),
    .PADDR              (apb_vif.PADDR),
    .PWRITE             (apb_vif.PWRITE),
    .PWDATA             (apb_vif.PWDATA),
    .apb_read_data_out  (apb_vif.apb_read_data_out),  // Read data to system
    .PSLVERR            (apb_vif.PSLVERR)
  );

  initial begin
    // two, we use UVM's Configuration Database (uvm_config_db).
    //   1. cntxt (context): uvm_component parent context.
    //        Passing `null` makes this entry global or anchored to the root.
    //   2. inst_name (instance name): Path string to target components.
    //      - We pass `"*"` (wildcard) which means *all* components in the testbench
    //        hierarchy will have permission to read this entry. If we wanted to
    //        restrict it, we could pass `"uvm_test_top.env.agent.drv"`.
    //        must query the database with this exact string name.
    uvm_config_db #(virtual apb_if)::set(null, "*", "vif", apb_vif);

    // NOTE: Requires "-access +rwc" in the xrun command for Xcelium.
    $dumpfile("apb_master_tb.vcd");
    $dumpvars(0, tb_top);

    // STARTING THE UVM ENGINE: run_test()
    // run_test() is a global UVM task that does the following:
    //      - PARALLEL: run_phase (time-consuming simulation tasks)
    //      - BOTTOM-UP: extract_phase, check_phase, report_phase, final_phase
    run_test();
  end

endmodule
