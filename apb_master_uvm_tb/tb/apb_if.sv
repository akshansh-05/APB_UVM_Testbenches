// apb_if.sv: APB Virtual Interface
interface apb_if (
  input logic PCLK,
  input logic PRESETn
);

  // System-side signals
  logic [8:0] apb_write_paddr;
  logic [8:0] apb_read_paddr;
  logic [7:0] apb_write_data;
  logic       READ_WRITE;
  logic       transfer;
  logic [7:0] apb_read_data_out;

  // Slave response signals
  logic [7:0] PRDATA;
  logic       PREADY;

  // APB bus signals
  logic       PSEL1;
  logic       PSEL2;
  logic       PENABLE;
  logic [8:0] PADDR;
  logic       PWRITE;
  logic [7:0] PWDATA;

  // System driver clocking block
  clocking master_cb @(posedge PCLK);
    default input #1ns output #1ns;
    output transfer, READ_WRITE, apb_write_paddr, apb_read_paddr, apb_write_data;
    input  apb_read_data_out, PREADY, PENABLE;
  endclocking

  // Slave driver clocking block
  clocking slave_cb @(posedge PCLK);
    default input #1ns output #1ns;
    input  PSEL1, PSEL2, PENABLE, PADDR, PWRITE, PWDATA;
    output PREADY, PRDATA;
  endclocking

  // System monitor clocking block
  clocking sys_monitor_cb @(posedge PCLK);
    default input #1ns;
    input transfer, READ_WRITE, apb_write_paddr, apb_read_paddr, apb_write_data, apb_read_data_out;
    input PREADY, PENABLE, PSEL1, PSEL2;
  endclocking

  // Bus monitor clocking block
  clocking monitor_cb @(posedge PCLK);
    default input #1ns;
    input PSEL1, PSEL2, PENABLE, PADDR, PWRITE, PWDATA, PREADY, PRDATA;
  endclocking

  modport master_mp (clocking master_cb, input PCLK, input PRESETn);
  modport slave_mp  (clocking slave_cb,  input PCLK, input PRESETn);
  modport sys_monitor_mp (clocking sys_monitor_cb, input PCLK, input PRESETn);
  modport monitor_mp (clocking monitor_cb, input PCLK, input PRESETn);

endinterface
