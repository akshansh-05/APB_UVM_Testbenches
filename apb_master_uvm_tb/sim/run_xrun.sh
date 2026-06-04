#!/bin/bash
# ==============================================================================
# FILE: run_xrun.sh
# DESCRIPTION:
#   Cadence Xcelium simulation script for APB Master Bridge testbench.
#
#   HOW TO RUN:
#     cd sim
#     chmod +x run_xrun.sh
#     ./run_xrun.sh
# ==============================================================================

xrun -uvm -sv \
  -timescale 1ns/1ns \
  -access +rwc \
  +incdir+../tb \
  ../tb/apb_master_if.sv \
  ../tb/apb_master_pkg.sv \
  ../rtl/apb_master.sv \
  ../tb/tb_top.sv \
  +UVM_TESTNAME=apb_master_test \
  +UVM_VERBOSITY=UVM_MEDIUM
