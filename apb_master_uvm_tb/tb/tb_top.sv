`timescale 1ns/1ns

module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_pkg::*;

  logic PCLK;
  logic PRESETn;

  initial PCLK = 0;
  always #5 PCLK = ~PCLK;

  initial begin
    PRESETn = 0;
    #50;
    PRESETn = 1;
  end

  apb_if apb_vif(.PCLK(PCLK), .PRESETn(PRESETn));

  master_bridge dut (
    .PCLK              (PCLK),
    .PRESETn            (PRESETn),
    .apb_write_paddr    (apb_vif.apb_write_paddr),
    .apb_read_paddr     (apb_vif.apb_read_paddr),
    .apb_write_data     (apb_vif.apb_write_data),
    .READ_WRITE         (apb_vif.READ_WRITE),
    .transfer           (apb_vif.transfer),
    .PRDATA             (apb_vif.PRDATA),
    .PREADY             (apb_vif.PREADY),
    .PSEL1              (apb_vif.PSEL1),
    .PSEL2              (apb_vif.PSEL2),
    .PENABLE            (apb_vif.PENABLE),
    .PADDR              (apb_vif.PADDR),
    .PWRITE             (apb_vif.PWRITE),
    .PWDATA             (apb_vif.PWDATA),
    .apb_read_data_out  (apb_vif.apb_read_data_out),
    .PSLVERR            () // PSLVERR ignored
  );

  initial begin
    uvm_config_db #(virtual apb_if)::set(null, "*", "vif", apb_vif);
    $dumpfile("apb_master_tb.vcd");
    $dumpvars(0, tb_top);
    run_test();
  end

endmodule
