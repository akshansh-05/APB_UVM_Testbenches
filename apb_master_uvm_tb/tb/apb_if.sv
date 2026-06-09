// ============================================================================
// FILE: apb_if.sv
// DESCRIPTION: Parameterized SystemVerilog interface for the APB Master TB
// ============================================================================

interface apb_if #(
  parameter ADDR_WIDTH = 9,      // Defines the width of the Address bus (default: 9 bits)
  parameter DATA_WIDTH = 8       // Defines the width of the Data bus (default: 8 bits)
)(
  input logic PCLK,              // Clock input signal from the testbench top generator
  input logic PRESETn            // Reset input signal (active-low) from testbench top
);

  // ---- SYSTEM-SIDE SIGNALS ----
  logic [ADDR_WIDTH-1:0] apb_write_paddr;  // Address driven for system write requests
  logic [ADDR_WIDTH-1:0] apb_read_paddr;   // Address driven for system read requests
  logic [DATA_WIDTH-1:0] apb_write_data;   // Data payload driven for system write requests
  logic                  READ_WRITE;       // Direction flag driven by system: 1=Read, 0=Write
  logic                  transfer;         // Transfer start strobe driven by system to DUT
  logic [DATA_WIDTH-1:0] apb_read_data_out;// Read data output returned by the DUT to the system

  // ---- SLAVE RESPONSE SIGNALS ----
  logic [DATA_WIDTH-1:0] PRDATA;           // Data driven by the slave onto the APB bus during reads
  logic                  PREADY;           // Ready indicator driven by the slave to complete handshake

  // ---- APB BUS OUTPUT SIGNALS ----
  logic                  PSEL1;            // Slave 1 select line driven by the Master DUT
  logic                  PSEL2;            // Slave 2 select line driven by the Master DUT
  logic                  PENABLE;          // Strobe signal indicating the Access phase driven by DUT
  logic [ADDR_WIDTH-1:0] PADDR;            // Address driven on the APB bus by the Master DUT
  logic                  PWRITE;           // Direction indicator on the APB bus: 1=Write, 0=Read
  logic [DATA_WIDTH-1:0] PWDATA;           // Data payload driven on the APB bus by the Master DUT
  logic                  PSLVERR;          // Error feedback driven by the slave to the Master DUT

  // ---- CLOCKING BLOCK FOR MASTER DRIVER ----
  clocking master_cb @(posedge PCLK);
    default input #1ns output #1ns;        // Establishes 1ns setup and hold times for signals
    output transfer;                       // System driver outputs the transfer request to the DUT
    output READ_WRITE;                     // System driver outputs the direction flag to the DUT
    output apb_write_paddr;                // System driver outputs the write address to the DUT
    output apb_read_paddr;                 // System driver outputs the read address to the DUT
    output apb_write_data;                 // System driver outputs the write data payload to the DUT
    input  apb_read_data_out;              // System driver reads back the read data output from the DUT
    input  PREADY;                         // System driver reads the APB ready flag driven by the slave
    input  PENABLE;                        // System driver reads the APB enable strobe driven by the Master DUT
    input  PSLVERR;                        // System driver reads the APB slave error flag driven by the slave
  endclocking                              // End of master driver clocking block declaration

  // ---- CLOCKING BLOCK FOR SLAVE DRIVER ----
  clocking slave_cb @(posedge PCLK);
    default input #1ns output #1ns;        // Sets default setup and hold skew values to 1ns
    input  PSEL1;                          // Slave driver inputs the Slave 1 chip select line from DUT
    input  PSEL2;                          // Slave driver inputs the Slave 2 chip select line from DUT
    input  PENABLE;                        // Slave driver inputs the access phase enable signal from DUT
    input  PADDR;                          // Slave driver inputs the active APB address bus from DUT
    input  PWRITE;                         // Slave driver inputs the APB write/read direction from DUT
    input  PWDATA;                         // Slave driver inputs the active APB write data bus from DUT
    output PREADY;                         // Slave driver outputs the ready completion flag onto the bus
    output PRDATA;                         // Slave driver outputs the read data payload onto the bus
  endclocking                              // End of slave driver clocking block declaration

  // ---- CLOCKING BLOCK FOR SYSTEM MONITOR ----
  clocking sys_monitor_cb @(posedge PCLK);
    default input #1ns;                    // Samples all inputs 1ns before the active clock edge
    input transfer;                        // System monitor samples the transfer request signal
    input READ_WRITE;                      // System monitor samples the system direction signal
    input apb_write_paddr;                 // System monitor samples the system write address input
    input apb_read_paddr;                  // System monitor samples the system read address input
    input apb_write_data;                  // System monitor samples the system write data input
    input apb_read_data_out;               // System monitor samples the system read data output from DUT
    input PREADY;                          // System monitor samples the ready handshake driven by the slave
  endclocking                              // End of system monitor clocking block declaration

  // ---- CLOCKING BLOCK FOR APB BUS MONITOR ----
  clocking monitor_cb @(posedge PCLK);
    default input #1ns;                    // Samples bus signals 1ns prior to the rising edge of clock
    input PSEL1;                           // APB monitor samples the Slave 1 chip select signal
    input PSEL2;                           // APB monitor samples the Slave 2 chip select signal
    input PENABLE;                         // APB monitor samples the active transfer enable signal
    input PADDR;                           // APB monitor samples the address bus driven by the Master
    input PWRITE;                          // APB monitor samples the write/read flag driven by the Master
    input PWDATA;                          // APB monitor samples the write data bus driven by the Master
    input PREADY;                          // APB monitor samples the ready handshake driven by the Slave
    input PRDATA;                          // APB monitor samples the read data bus driven by the Slave
    input PSLVERR;                         // APB monitor samples the error signal driven by the Slave
  endclocking                              // End of APB monitor clocking block declaration

  // ---- MODPORTS DEFINING PORT DIRECTIONS ----
  modport master_mp (clocking master_cb, input PCLK, input PRESETn);           // Master driver modport
  modport slave_mp  (clocking slave_cb,  input PCLK, input PRESETn);           // Slave driver modport
  modport sys_monitor_mp (clocking sys_monitor_cb, input PCLK, input PRESETn); // System monitor modport
  modport monitor_mp (clocking monitor_cb, input PCLK, input PRESETn);         // Standalone APB monitor modport

endinterface // End of apb_if interface declaration
