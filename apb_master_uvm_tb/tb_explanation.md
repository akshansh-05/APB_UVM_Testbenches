# APB Master UVM Testbench: Architecture & Logic Explanation

This document provides a detailed walkthrough of every file and component in the refactored APB Master Bridge testbench, explaining the underlying logical execution and connection flows.

---

## 1. Directory Structure

```
apb_master_uvm_tb/
├── rtl/
│   └── apb_master.sv                 # The FSM-based Master Bridge DUT
└── tb/
    ├── apb_if.sv                      # Parameterized virtual interface with modports
    ├── apb_seq_item.sv                # Transaction packet class (address, data, flags)
    ├── apb_sequencer.sv               # Sequencer typedef mapping transactions to driver
    ├── apb_sys_driver.sv              # Active driver driving DUT's system inputs
    ├── apb_sys_monitor.sv             # Passive monitor inside sys_agent tracking system commands
    ├── apb_sys_agent.sv               # Active agent grouping system driver, monitor, and sequencer
    ├── apb_slv_driver.sv              # Reactive driver emulating slave memory on APB bus
    ├── apb_slv_agent.sv               # Reactive agent containing only the slave driver
    ├── apb_monitor.sv                 # Standalone monitor tracking APB bus handshakes
    ├── apb_scoreboard.sv              # Checker scoreboard comparing inputs and outputs
    ├── apb_env.sv                     # Environment class instantiating and wiring all components
    ├── apb_sequences.sv               # Stimulus sequences (1 write followed by 1 read)
    ├── apb_test.sv                    # Base test and concrete write-read test class
    ├── apb_pkg.sv                     # Compilation package wrapping all class files
    └── tb_top.sv                      # Top-level SystemVerilog module
```

---

## 2. Component Explanations & Logic Flow

### [tb/apb_if.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_if.sv) - Virtual Interface
*   **Role**: Serves as the physical-to-virtual connection bridge between the static RTL design and dynamic class-based UVM components.
*   **Logic & Structure**:
    *   It is parameterized: `# (parameter ADDR_WIDTH = 9, DATA_WIDTH = 8)`. This supports changing the address/data width without modifying port declarations.
    *   Defines three separate `clocking blocks` to establish cycle-accurate, race-free signal driving and sampling:
        1.  `master_cb`: Used by the system driver to drive requests (`transfer`, `READ_WRITE`, etc.) and sample DUT state.
        2.  `slave_cb`: Used by the slave driver to sample selects/strobes and drive responses (`PREADY`, `PRDATA`).
        3.  `sys_monitor_cb` & `monitor_cb`: Input-only blocks used by monitors to sample pins 1ns before clock edges.
    *   Defines corresponding `modports` (`master_mp`, `slave_mp`, etc.) to enforce strict signal direction constraints.

---

### [tb/apb_seq_item.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_seq_item.sv) - Sequence Item
*   **Role**: The fundamental data container representing a single transaction packet.
*   **Logic & Structure**:
    *   Extends `uvm_sequence_item`. It is a dynamic object created on the fly.
    *   Contains two sets of fields:
        1.  **Stimulus Fields (`addr`, `wdata`, `read`)**: Randomized by sequences and read by the system driver.
        2.  **Monitor Fields (`paddr`, `pwdata`, `pwrite`, etc.)**: Sampled from the physical pins by the monitors for scoreboard checking.
    *   Utilizes UVM field automation macros (`uvm_field_int`) to automatically implement standard utilities like `copy`, `compare`, `print`, and `sprint`.

---

### [tb/apb_sequencer.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_sequencer.sv) - Sequencer Typedef
*   **Role**: Coordinates the transfer of sequence items between stimulus sequences and the driver.
*   **Logic & Structure**:
    *   Declared as a `typedef` alias: `typedef uvm_sequencer #(apb_seq_item) apb_sequencer;`.
    *   Because it requires no custom variables or overridden functions, UVM's standard parameterized sequencer is used directly to manage the stimulus queue.

---

### [tb/apb_sys_driver.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_sys_driver.sv) - Active System Driver
*   **Role**: Consumes sequence items and drives them onto the DUT's system-side ports.
*   **Logic & Structure**:
    *   Sits in a `forever` loop inside its `run_phase` task.
    *   Retrieves a transaction item via `seq_item_port.get_next_item(item)`.
    *   **Driving logic**: Drives the request pins (`transfer <= 1`, `READ_WRITE <= item.read`, address, and write data) using non-blocking assignments (`<=`) through `vif.master_cb` to avoid race conditions.
    *   **Handshake logic**: Executes a loop polling `vif.master_cb.PREADY` each clock cycle. When `PREADY` is detected high, it captures read data (if applicable) and releases the system request (`transfer <= 0`).
    *   Calls `seq_item_port.item_done()` to unblock the sequence.

---

### [tb/apb_sys_monitor.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_sys_monitor.sv) - Passive System Monitor
*   **Role**: Passively collects the system-side requests driven into the DUT and broadcasts them as verification expectations.
*   **Logic & Structure**:
    *   Sits in a `forever` loop inside `run_phase` sampling signals via `vif.sys_monitor_cb`.
    *   When it detects `transfer` is high, it instantiates an `apb_seq_item` and records the system direction (`read`), address, and write data.
    *   It waits until `vif.sys_monitor_cb.PREADY` goes high, samples the resulting `apb_read_data_out` (for read commands), and broadcasts the packet via `ap.write(item)` to the scoreboard's `exp_port`.

---

### [tb/apb_sys_agent.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_sys_agent.sv) - Active System Agent
*   **Role**: Bundles the sequencer, system driver, and system monitor into a single, cohesive interface controller.
*   **Logic & Structure**:
    *   In the `build_phase`: Instantiates the system monitor. If `is_active` is set to `UVM_ACTIVE`, it also instantiates the sequencer and system driver.
    *   In the `connect_phase`: Connects the driver's `seq_item_port` to the sequencer's `seq_item_export` if active.

---

### [tb/apb_slv_driver.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_slv_driver.sv) - Reactive Slave Driver
*   **Role**: Emulates a physical memory-mapped APB slave device by responding reactively to bus handshakes.
*   **Logic & Structure**:
    *   Maintains a local associative array: `protected bit [7:0] slave_mem [bit [8:0]]`.
    *   Monitors `PSEL1` and `PSEL2` signals.
    *   **SETUP Phase (PENABLE is low)**: Assert `PREADY <= 1'b1` to signify it will be ready in the next cycle (ACCESS phase). If it's a read (`!PWRITE`), it retrieves the data from `slave_mem[PADDR]` (or recomputes the fallback XOR pattern if address never written) and drives it on `PRDATA`.
    *   **ACCESS Phase (PENABLE is high, PREADY is high)**: At the rising clock edge when the handshake completes, if it was a write (`PWRITE` high), it captures the write data from the bus and saves it: `slave_mem[PADDR] = PWDATA`. It then deasserts `PREADY <= 1'b0`.

---

### [tb/apb_slv_agent.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_slv_agent.sv) - Slave Agent
*   **Role**: Bundles the reactive slave driver.
*   **Logic & Structure**:
    *   Instantiates the `apb_slv_driver` during `build_phase`. Since this agent is purely reactive, it needs no sequencer or monitor.

---

### [tb/apb_monitor.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_monitor.sv) - Standalone APB Monitor
*   **Role**: Observes the physical APB bus signals between the master DUT and the slave responder.
*   **Logic & Structure**:
    *   Samples signals on `vif.monitor_cb` at every rising clock edge.
    *   Checks for a completed APB transfer handshake: `PENABLE == 1 && PREADY == 1 && (PSEL1 || PSEL2)`.
    *   Reconstructs the transaction details (`PADDR`, `PWDATA`, `PRDATA`, selects, direction, error flags) into a new `apb_seq_item` and broadcasts it via `ap.write(item)` to the scoreboard's `act_port`.

---

### [tb/apb_scoreboard.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_scoreboard.sv) - Checker Scoreboard
*   **Role**: Receives expected commands (from `sys_agent.monitor`) and actual bus transfers (from environment `apb_monitor`), comparing them for correctness.
*   **Logic & Structure**:
    *   Uses `uvm_analysis_imp_decl` macros to implement two independent ports:
        1.  `exp_port` (expected): Triggers `write_expected(item)`. Pushes the item to a FIFO queue (`exp_q`) and saves write commands into its local reference memory (`ref_mem`).
        2.  `act_port` (actual): Triggers `write_actual(item)`. Pops the corresponding item from `exp_q` and executes checks.
    *   **Checks performed**:
        *   Checks direction (`pwrite == ~read`).
        *   Checks addresses (`paddr == addr`).
        *   Checks write data matching (`pwdata == wdata`).
        *   Checks Slave Select chip routing based on address bit 8 (`PADDR[8]`).
        *   Checks read data coherence: Compares actual read data on bus (`rdata`) against data stored in scoreboard's `ref_mem` (or XOR fallback).
        *   Checks system propagation: Verifies that the system-side read data output matches the bus-side read data.

---

### [tb/apb_env.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_env.sv) - Environment Container
*   **Role**: Instantiates and wires together all agents and checker blocks.
*   **Logic & Structure**:
    *   `build_phase`: Instantiates `sys_agent`, `slv_agent`, `monitor`, and `scoreboard`.
    *   `connect_phase`: Hooks up the TLM connections:
        *   `sys_agent.mon.ap` -> `scoreboard.exp_port`
        *   `monitor.ap` -> `scoreboard.act_port`

---

### [tb/apb_sequences.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_sequences.sv) - Stimulus Sequences
*   **Role**: Generates the high-level stimulus transactions.
*   **Logic & Structure**:
    *   Contains the `apb_write_read_seq` sequence.
    *   **Logic**:
        1.  Generates exactly 1 write item targeting address offset `0x10` with data payload `0xBE` on Slave 1.
        2.  Calls `start_item` and `finish_item` to execute the write.
        3.  Generates 1 read item targeting the same address.
        4.  Calls `start_item` and `finish_item` to execute the read.

---

### [tb/apb_test.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_test.sv) - UVM Test Class
*   **Role**: Configures the testbench hierarchy and triggers sequence execution.
*   **Logic & Structure**:
    *   `test_apb_base`: Instantiates the env during `build_phase`.
    *   `apb_master_test`: Extends the base test. Its `run_phase` raises a UVM objection, waits for reset to clear, creates and starts `apb_write_read_seq` on `env.sys_agent.sqr`, waits for completion, and drops the objection.

---

### [tb/apb_pkg.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/apb_pkg.sv) - Package Wrapper
*   **Role**: Combines all verification class scopes into a single compilation unit.
*   **Logic & Structure**:
    *   Declared as `package apb_pkg;`.
    *   Imports `uvm_pkg::*` and includes `uvm_macros.svh`.
    *   Includes all class files in strict order of dependency to prevent compilation errors (e.g. including `apb_seq_item` first, and `apb_test` last).

---

### [tb/tb_top.sv](file:///c:/Users/HP/Downloads/apb_master_uvm_tb/apb_master_uvm_tb/tb/tb_top.sv) - Top-Level Testbench
*   **Role**: Connects static hardware structures (the RTL DUT) to the dynamic software structures (UVM components).
*   **Logic & Structure**:
    *   Generates clock and active-low reset signals.
    *   Instantiates the physical interface `apb_if` and the DUT `master_bridge`.
    *   Maps DUT ports to the interface wires.
    *   `initial begin`: 
        *   Registers the virtual interface handle in the `uvm_config_db`: `uvm_config_db #(virtual apb_if)::set(null, "*", "vif", apb_vif);`.
        *   Sets up VCD waveform dumping.
        *   Invokes `run_test()`, starting the UVM engine.
