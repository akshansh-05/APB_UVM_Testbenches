# APB UVM Testbenches

A repository containing complete, working UVM (Universal Verification Methodology) testbenches for APB (Advanced Peripheral Bus) Slave and Master controllers, developed as part of a SystemVerilog/UVM training course.

## Repository Structure

```
APB_UVM_Testbenches/
├── apb_slave_uvm_tb/     # UVM Testbench for APB Slave DUT (Memory-based)
│   ├── rtl/              # DUT design file (apb_slave.sv)
│   ├── tb/               # UVM testbench component files
│   └── sim/              # QuestaSim/ModelSim run script (run.do)
│
└── apb_master_uvm_tb/    # UVM Testbench for APB Master DUT (FSM-based Bridge)
    ├── rtl/              # DUT design file (apb_master.sv)
    ├── tb/               # UVM testbench component files
    └── sim/              # QuestaSim/ModelSim run script (run.do)
```

---

## 1. APB Slave Testbench
- **DUT:** Memory-mapped APB slave containing an internal 256x8 memory array.
- **Verification Strategy:** Drives standard APB read/write protocol sequences.
- **Scoreboard:** Uses an associative array to model reference memory, verifying write data storage and read data accuracy.

## 2. APB Master Testbench
- **DUT:** APB Master Bridge translating system-level commands to APB transactions.
- **Verification Strategy:** Drives system-side interfaces (commands, addresses, data) and handles APB handshakes. Includes an emulated **zero-wait-state slave responder** in `tb_top.sv` to complete transactions.
- **Scoreboard:** Validates address routing (PSEL1/PSEL2), PSLVERR response flag behavior, and read data correctness.

---

## How to Run Simulations

### ModelSim / QuestaSim (GUI)
1. Open ModelSim/QuestaSim.
2. Navigate to the desired testbench `sim` directory (e.g., `APB_UVM_Testbenches/apb_slave_uvm_tb/sim`).
3. Run:
   ```tcl
   do run.do
   ```

### VCS (Synopsys)
Navigate to the testbench directory and run:
```bash
# Example for APB Master
vcs -sverilog -ntb_opts uvm +incdir+../tb \
    ../tb/apb_master_if.sv ../tb/apb_master_pkg.sv \
    ../rtl/apb_master.sv ../tb/tb_top.sv -o simv
./simv +UVM_TESTNAME=apb_master_test +UVM_VERBOSITY=UVM_MEDIUM
```

### Xcelium (Cadence)
Navigate to the testbench directory and run:
```bash
# Example for APB Master
xrun -sv -uvm +incdir+../tb \
    ../tb/apb_master_if.sv ../tb/apb_master_pkg.sv \
    ../rtl/apb_master.sv ../tb/tb_top.sv \
    +UVM_TESTNAME=apb_master_test +UVM_VERBOSITY=UVM_MEDIUM
```
