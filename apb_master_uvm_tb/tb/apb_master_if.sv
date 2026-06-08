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
//
//   SIGNAL FLOW SUMMARY:
//   ┌──────────┐    system signals     ┌──────────┐    APB signals    ┌───────────┐
//   │ UVM      │ ───────────────────→  │ Master   │ ───────────────→  │ APB Slave  │
//   │ Driver   │  (transfer, addr,     │ Bridge   │  (PSEL, PENABLE, │ Responder  │
//   │          │   wdata, READ_WRITE)  │ DUT      │   PADDR, PWDATA) │ (in tb_top)│
//   └──────────┘                       └──────────┘  ←──────────────  └───────────┘
//                                                    (PREADY, PRDATA)
// ============================================================================

// Interface declaration with clock and reset as input ports.
// These are passed from tb_top when instantiating the interface.
interface apb_master_if(input logic PCLK, input logic PRESETn);

  // ===================== SYSTEM-SIDE SIGNALS =====================
  // These signals go INTO the DUT (master_bridge).
  // The UVM Driver sets these to request a read or write transfer.

  logic [8:0] apb_write_paddr;   // 9-bit write address; bit[8] selects which slave
  logic [8:0] apb_read_paddr;    // 9-bit read address; bit[8] selects which slave
  logic [7:0] apb_write_data;    // 8-bit data payload for write transfers
  logic       READ_WRITE;        // Direction control: 1 = Read, 0 = Write
  logic       transfer;          // Transfer request: 1 = start a new APB transfer

  // ===================== SLAVE RESPONSE SIGNALS ==================
  // These signals come FROM the slave (responder in tb_top) INTO the DUT.
  // They tell the master when the slave is ready and provide read data.

  logic [7:0] PRDATA;            // Read data returned by the slave
  logic       PREADY;            // Slave ready: 1 = slave has completed its part

  // ===================== APB BUS OUTPUT SIGNALS ==================
  // These signals come OUT of the DUT onto the APB bus.
  // The UVM Monitor observes these to verify correct protocol behavior.

  logic       PSEL1;             // Slave 1 chip-select (active when addr[8]=0)
  logic       PSEL2;             // Slave 2 chip-select (active when addr[8]=1)
  logic       PENABLE;           // APB enable: goes high during the ACCESS phase
  logic [8:0] PADDR;             // APB address bus driven by the master
  logic       PWRITE;            // APB direction: 1=write, 0=read
  logic [7:0] PWDATA;            // APB write data bus driven by the master
  logic [7:0] apb_read_data_out; // Read data output: DUT passes PRDATA to system
  logic       PSLVERR;           // Slave error flag (1 = error detected)

  // ---- Clocking Block for Driver ----
  // A clocking block defines WHEN signals are driven/sampled relative to the clock.
  // The driver drives system-side signals (output) and reads APB outputs (input)
  // to know when a transfer completes.
  // "default input #1 output #1" means:
  //   - sample inputs 1ns BEFORE the posedge (setup time)
  //   - drive outputs 1ns AFTER the posedge (hold time)
  // This prevents race conditions between driving and sampling.
  clocking driver_cb @(posedge PCLK);
    default input #1 output #1;

    // System-side: the driver DRIVES these into the DUT
    output transfer;
    output READ_WRITE;
    output apb_write_paddr;
    output apb_read_paddr;
    output apb_write_data;

    // APB-side: the driver READS these to monitor the DUT's progress
    input  PREADY;             // Check if slave responded
    input  PENABLE;            // Check if DUT is in ACCESS phase
    input  PSEL1;              // Check which slave is selected
    input  PSEL2;
    input  PADDR;              // Observe the address on APB bus
    input  PWRITE;             // Observe write/read direction
    input  PWDATA;             // Observe write data on APB bus
    input  apb_read_data_out;  // Capture read data after a read transfer
    input  PSLVERR;            // Check for slave errors
  endclocking

  // ---- Clocking Block for Monitor ----
  // The monitor is PASSIVE — it only observes, never drives.
  // All signals are declared as "input" so the monitor can sample them.
  // "default input #1" means sample 1ns before the clock edge.
  clocking monitor_cb @(posedge PCLK);
    default input #1;

    // System-side signals (observe what the driver requested)
    input transfer;
    input READ_WRITE;
    input apb_write_paddr;
    input apb_read_paddr;
    input apb_write_data;

    // Slave response signals (observe what the slave returned)
    input PRDATA;
    input PREADY;

    // APB bus output signals (observe what the DUT generated)
    input PSEL1;
    input PSEL2;
    input PENABLE;
    input PADDR;
    input PWRITE;
    input PWDATA;
    input apb_read_data_out;
    input PSLVERR;
  endclocking

  // ---- Clocking Block for Slave Driver ----
  // The slave driver reads APB signals from the master and drives PREADY/PRDATA
  clocking slave_cb @(posedge PCLK);
    default input #1 output #1;
    input  PSEL1;
    input  PSEL2;
    input  PENABLE;
    input  PADDR;
    input  PWRITE;
    input  PWDATA;
    output PREADY;
    output PRDATA;
  endclocking

  // ---- Modports ----
  // Modports restrict which signals/clocking blocks a component can access.
  // "driver" modport  → can use driver_cb (drive system signals, read APB signals)
  // "monitor" modport → can use monitor_cb (read-only access to all signals)
  // "slave_driver" modport → can use slave_cb (drive PREADY/PRDATA, read APB signals)
  // Both get direct access to PCLK and PRESETn for reset handling.
  modport driver  (clocking driver_cb,  input PCLK, input PRESETn);
  modport monitor (clocking monitor_cb, input PCLK, input PRESETn);
  modport slave_driver (clocking slave_cb, input PCLK, input PRESETn);

endinterface
