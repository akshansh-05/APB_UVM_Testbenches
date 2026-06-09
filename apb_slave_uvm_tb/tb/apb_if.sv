//   testbench and the DUT.

interface apb_if(input logic PCLK, input logic PRESETn);

  logic        PSEL;       // Slave select (driven by testbench)
  logic        PENABLE;
  logic        PWRITE;     // 1 = Write, 0 = Read (driven by testbench)
  logic [7:0]  PADDR;
  logic [7:0]  PWDATA;
  logic [7:0]  PRDATA1;
  logic        PREADY;

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

  modport driver  (clocking driver_cb,  input PCLK, input PRESETn);
  modport monitor (clocking monitor_cb, input PCLK, input PRESETn);

endinterface
