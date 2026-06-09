#!/bin/bash
# ==============================================================================
# FILE: run_xrun.sh
# DESCRIPTION:
#   Cadence Xcelium simulation script for APB Master Bridge testbench.
#
#   This script compiles, elaborates, and simulates the entire testbench
#   in a single xrun command (single-step flow).
#
#   HOW TO RUN:
#     cd sim
#     chmod +x run_xrun.sh      # Make executable (first time only)
#     ./run_xrun.sh
#
#   XRUN FLAGS EXPLAINED:
#     -uvm              : Enable built-in UVM library support
#     -sv               : Enable SystemVerilog language features
#     -timescale 1ns/1ns: Set default timescale for files without `timescale
#     -access +rwc      : Enable read/write/connectivity access for waveform
#                         dumping ($dumpvars requires this on Xcelium)
#     +incdir+../tb     : Add ../tb to the include search path so that
#                         `include directives in apb_master_pkg.sv can find
#                         the .sv files in the tb/ directory
#     +UVM_TESTNAME     : Tells UVM which test class to create and run
#     +UVM_VERBOSITY    : Controls how much log output UVM prints
#                         (UVM_NONE < UVM_LOW < UVM_MEDIUM < UVM_HIGH < UVM_FULL)
#
#   FILE ORDER MATTERS:
#     1. apb_master_if.sv  → Interface (needed by everything)
#     2. apb_master_pkg.sv → Package (includes all UVM classes)
#     3. apb_master.sv     → RTL design (the DUT)
#     4. tb_top.sv         → Top module (instantiates interface, DUT, starts UVM)
# ==============================================================================

xrun -uvm -sv \
  -timescale 1ns/1ns \
  -access +rwc \
  +incdir+../tb \
  ../tb/apb_if.sv \
  ../tb/apb_pkg.sv \
  ../rtl/apb_master.sv \
  ../tb/tb_top.sv \
  +UVM_TESTNAME=apb_master_test \
  +UVM_VERBOSITY=UVM_MEDIUM
