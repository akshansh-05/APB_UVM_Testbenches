// ============================================================================
// FILE: apb_if.sv
// DESCRIPTION:
//   SystemVerilog Interface for APB bus signals.
//
//   WHY AN INTERFACE?
//   -----------------
//   An interface bundles all the APB signals into one "cable" so that:
//     1. The DUT, driver, and monitor all connect to the same signals.
//     2. We avoid passing dozens of individual wires around.
//
//   WHAT IS A CLOCKING BLOCK?
//   -------------------------
//   A clocking block tells the driver/monitor WHEN to drive/sample signals
//   relative to the clock edge. This prevents race conditions between the
//   testbench and the DUT.
// ============================================================================

interface apb_if(input logic PCLK, input logic PRESETn);

  // ---- APB Bus Signals ----
  logic        PSEL;       // Slave select (driven by testbench)
  logic        PENABLE;    // Enable signal (driven by testbench)
  logic        PWRITE;     // 1 = Write, 0 = Read (driven by testbench)
  logic [7:0]  PADDR;      // Address bus (driven by testbench)
  logic [7:0]  PWDATA;     // Write data bus (driven by testbench)
  logic [7:0]  PRDATA1;    // Read data bus (driven by DUT)
  logic        PREADY;     // Slave ready signal (driven by DUT)

  // ---- Clocking Block for Driver ----
  // Drives inputs on the clock edge, samples outputs slightly after
  clocking driver_cb @(posedge PCLK);
    default input #1 output #1;   // 1ns setup/hold time
    output PSEL;
    output PENABLE;
    output PWRITE;
    output PADDR;
    output PWDATA;
    input  PRDATA1;
    input  PREADY;
  endclocking

  // ---- Clocking Block for Monitor ----
  // Only samples signals (never drives them)
  clocking monitor_cb @(posedge PCLK);
    default input #1;
    input PSEL;
    input PENABLE;
    input PWRITE;
    input PADDR;
    input PWDATA;
    input PRDATA1;
    input PREADY;
  endclocking

  // ---- Modports ----
  // Modports restrict which clocking block each component can use.
  modport driver  (clocking driver_cb,  input PCLK, input PRESETn);
  modport monitor (clocking monitor_cb, input PCLK, input PRESETn);

endinterface
