# ==============================================================================
# FILE: run.do
# DESCRIPTION:
#   QuestaSim/ModelSim simulation script.
#
#   HOW TO USE:
#   -----------
#   1. Open QuestaSim or ModelSim
#   2. Navigate to the project's sim/ directory:
#        cd C:/Users/HP/Desktop/APB_UVM_Testbenches/apb_slave_uvm_tb/sim
#   3. Run this script:
#        do run.do
#
#   WHAT THIS SCRIPT DOES:
#   1. Creates a work library
#   2. Compiles the interface, package, RTL, and top module
#   3. Runs the simulation with the UVM test
#   4. Opens waveforms (optional)
# ==============================================================================

# ---- Step 1: Create the work library ----
vlib work
vmap work work

# ---- Step 2: Compile all files ----
# Order matters! Interface and package must come before the top module.

# Compile the APB interface first (it defines signal types)
vlog -sv ../tb/apb_if.sv

# Compile the UVM package (contains all UVM class files)
# +incdir tells the compiler where to find the `include files
vlog -sv +incdir+../tb ../tb/apb_pkg.sv

# Compile the RTL (DUT)
vlog -sv ../rtl/apb_slave.sv

# Compile the top-level testbench module
vlog -sv +incdir+../tb ../tb/tb_top.sv

# ---- Step 3: Run the simulation ----
# +UVM_TESTNAME tells UVM which test class to create and run
# +UVM_VERBOSITY controls how much log output you see:
#   UVM_LOW    = minimal output
#   UVM_MEDIUM = moderate output (default, recommended)
#   UVM_HIGH   = verbose output
#   UVM_DEBUG  = extremely verbose
vsim -voptargs="+acc" work.tb_top +UVM_TESTNAME=apb_test +UVM_VERBOSITY=UVM_MEDIUM

# ---- Step 4: Add signals to waveform (optional) ----
add wave -position insertpoint sim:/tb_top/PCLK
add wave -position insertpoint sim:/tb_top/PRESETn
add wave -position insertpoint sim:/tb_top/apb_vif/PSEL
add wave -position insertpoint sim:/tb_top/apb_vif/PENABLE
add wave -position insertpoint sim:/tb_top/apb_vif/PWRITE
add wave -position insertpoint sim:/tb_top/apb_vif/PADDR
add wave -position insertpoint sim:/tb_top/apb_vif/PWDATA
add wave -position insertpoint sim:/tb_top/apb_vif/PRDATA1
add wave -position insertpoint sim:/tb_top/apb_vif/PREADY

# ---- Step 5: Run the simulation ----
run -all
