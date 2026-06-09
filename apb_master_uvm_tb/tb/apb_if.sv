interface apb_if (
  input logic PCLK,
  input logic PRESETn
);

  logic [8:0] apb_write_paddr;   // 9-bit address driven for system write requests
  logic [8:0] apb_read_paddr;    // 9-bit address driven for system read requests
  logic [7:0] apb_write_data;    // 8-bit data payload driven for system write requests
  logic       READ_WRITE;        // Direction flag driven by system: 1=Read, 0=Write
  logic       transfer;
  logic [7:0] apb_read_data_out;

  logic [7:0] PRDATA;
  logic       PREADY;

  logic       PSEL1;
  logic       PSEL2;
  logic       PENABLE;
  logic [8:0] PADDR;
  logic       PWRITE;
  logic [7:0] PWDATA;
  logic       PSLVERR;

  clocking master_cb @(posedge PCLK);
    // 1ns setup and hold skews prevent race conditions between the DUT and the testbench
    default input #1ns output #1ns;
    output transfer;
    output READ_WRITE;
    output apb_write_paddr;
    output apb_read_paddr;
    output apb_write_data;
    input  apb_read_data_out;
    input  PREADY;
    input  PENABLE;
    input  PSLVERR;
  endclocking

  clocking slave_cb @(posedge PCLK);
    default input #1ns output #1ns;
    input  PSEL1;                          // Slave driver inputs the Slave 1 chip select line from DUT
    input  PSEL2;                          // Slave driver inputs the Slave 2 chip select line from DUT
    input  PENABLE;
    input  PADDR;
    input  PWRITE;
    input  PWDATA;
    output PREADY;
    output PRDATA;
  endclocking

  clocking sys_monitor_cb @(posedge PCLK);
    default input #1ns;
    input transfer;
    input READ_WRITE;
    input apb_write_paddr;
    input apb_read_paddr;
    input apb_write_data;
    input apb_read_data_out;
    input PREADY;
  endclocking

  clocking monitor_cb @(posedge PCLK);
    default input #1ns;                    // Samples bus signals 1ns prior to the rising edge of clock
    input PSEL1;                           // APB monitor samples the Slave 1 chip select signal
    input PSEL2;                           // APB monitor samples the Slave 2 chip select signal
    input PENABLE;
    input PADDR;
    input PWRITE;
    input PWDATA;
    input PREADY;
    input PRDATA;
    input PSLVERR;
  endclocking

  modport master_mp (clocking master_cb, input PCLK, input PRESETn);
  modport slave_mp  (clocking slave_cb,  input PCLK, input PRESETn);
  modport sys_monitor_mp (clocking sys_monitor_cb, input PCLK, input PRESETn);
  modport monitor_mp (clocking monitor_cb, input PCLK, input PRESETn);

endinterface
