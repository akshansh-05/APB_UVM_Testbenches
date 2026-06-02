// ============================================================================
// FILE: apb_master_if.sv
// DESCRIPTION:
//   SystemVerilog Interface for the APB Master Bridge testbench.
//
//   The master bridge has TWO sides:
//     1. SYSTEM SIDE — inputs from the system (address, data, transfer request)
//        → Driven by the UVM Driver
//     2. APB BUS SIDE — outputs to the APB bus + slave responses
//        → APB outputs monitored by the UVM Monitor
//        → Slave responses (PREADY, PRDATA) driven by a slave responder
//
//   The clocking blocks ensure race-free signal driving and sampling.
// ============================================================================

interface apb_master_if(input logic PCLK, input logic PRESETn);

  // ===================== SYSTEM-SIDE SIGNALS =====================
  // These are INPUTS to the DUT, driven by the UVM Driver.
  logic [8:0] apb_write_paddr;   // Write address from system
  logic [8:0] apb_read_paddr;    // Read address from system
  logic [7:0] apb_write_data;    // Write data from system
  logic       READ_WRITE;        // 1 = Read, 0 = Write
  logic       transfer;          // 1 = Start a transfer

  // ===================== SLAVE RESPONSE SIGNALS ==================
  // These are INPUTS to the DUT, driven by the slave responder in tb_top.
  logic [7:0] PRDATA;            // Read data from slave
  logic       PREADY;            // Slave ready signal

  // ===================== APB BUS OUTPUT SIGNALS ==================
  // These are OUTPUTS from the DUT, observed by the UVM Monitor.
  logic       PSEL1;             // Slave 1 select (addr[8]=0)
  logic       PSEL2;             // Slave 2 select (addr[8]=1)
  logic       PENABLE;           // APB enable (ACCESS phase)
  logic [8:0] PADDR;             // APB address bus
  logic       PWRITE;            // APB write signal (1=write, 0=read)
  logic [7:0] PWDATA;            // APB write data bus
  logic [7:0] apb_read_data_out; // Read data output to system
  logic       PSLVERR;           // Slave error flag

  // ---- Clocking Block for Driver ----
  // The driver drives system-side signals and samples APB outputs.
  clocking driver_cb @(posedge PCLK);
    default input #1 output #1;
    // System-side outputs (driven by driver)
    output transfer;
    output READ_WRITE;
    output apb_write_paddr;
    output apb_read_paddr;
    output apb_write_data;
    // APB-side inputs (sampled by driver to know when transfer completes)
    input  PREADY;
    input  PENABLE;
    input  PSEL1;
    input  PSEL2;
    input  PADDR;
    input  PWRITE;
    input  PWDATA;
    input  apb_read_data_out;
    input  PSLVERR;
  endclocking

  // ---- Clocking Block for Monitor ----
  // The monitor only samples — it never drives.
  clocking monitor_cb @(posedge PCLK);
    default input #1;
    input transfer;
    input READ_WRITE;
    input apb_write_paddr;
    input apb_read_paddr;
    input apb_write_data;
    input PRDATA;
    input PREADY;
    input PSEL1;
    input PSEL2;
    input PENABLE;
    input PADDR;
    input PWRITE;
    input PWDATA;
    input apb_read_data_out;
    input PSLVERR;
  endclocking

  // ---- Modports ----
  modport driver  (clocking driver_cb,  input PCLK, input PRESETn);
  modport monitor (clocking monitor_cb, input PCLK, input PRESETn);

endinterface
