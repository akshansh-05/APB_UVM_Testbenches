//   This is the TOP-LEVEL MODULE of the entire testbench.
//   It is responsible for:
//     1. Generating the clock (PCLK)
//     2. Generating the reset (PRESETn)
//   3. Reset is applied for 5 clock cycles

`timescale 1ns/1ns

// The top-level testbench module generates clock and reset, instantiates
// the physical interfaces, wires the DUT, and triggers the UVM run phase.
module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_pkg::*;

  reg PCLK;
  reg PRESETn;

  initial PCLK = 0;
  always #5 PCLK = ~PCLK;   // Toggle every 5ns → 10ns period

  initial begin
    PRESETn = 0;       // Assert reset (active low)
    #50;
    PRESETn = 1;
    `uvm_info("TB_TOP", "Reset released", UVM_LOW)
  end

  apb_if apb_vif(.PCLK(PCLK), .PRESETn(PRESETn));

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

  initial begin
    uvm_config_db #(virtual apb_if)::set(null, "*", "vif", apb_vif);

    $dumpfile("apb_slave_tb.vcd");
    $dumpvars(0, tb_top);

    run_test();
  end

endmodule
