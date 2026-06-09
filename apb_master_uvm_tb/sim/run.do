# ==============================================================================
# FILE: run.do
# DESCRIPTION:
#   QuestaSim/ModelSim simulation script for APB Master Bridge testbench.
#
#   HOW TO USE:
#     cd C:/Users/HP/Desktop/APB_UVM_Testbenches/apb_master_uvm_tb/sim
#     do run.do
# ==============================================================================

# ---- Create work library ----
vlib work
vmap work work

# ---- Compile all files ----

# 1. Interface first
vlog -sv ../tb/apb_if.sv

# 2. UVM package (all class files)
vlog -sv +incdir+../tb ../tb/apb_pkg.sv

# 3. RTL (DUT)
vlog -sv ../rtl/apb_master.sv

# 4. Top-level testbench
vlog -sv +incdir+../tb ../tb/tb_top.sv

# ---- Run simulation ----
vsim -voptargs="+acc" work.tb_top +UVM_TESTNAME=apb_master_test +UVM_VERBOSITY=UVM_MEDIUM

# ---- Add waveforms ----
add wave -position insertpoint sim:/tb_top/PCLK
add wave -position insertpoint sim:/tb_top/PRESETn
# System-side signals
add wave -position insertpoint sim:/tb_top/apb_vif/transfer
add wave -position insertpoint sim:/tb_top/apb_vif/READ_WRITE
add wave -position insertpoint sim:/tb_top/apb_vif/apb_write_paddr
add wave -position insertpoint sim:/tb_top/apb_vif/apb_read_paddr
add wave -position insertpoint sim:/tb_top/apb_vif/apb_write_data
# APB bus signals
add wave -position insertpoint sim:/tb_top/apb_vif/PSEL1
add wave -position insertpoint sim:/tb_top/apb_vif/PSEL2
add wave -position insertpoint sim:/tb_top/apb_vif/PENABLE
add wave -position insertpoint sim:/tb_top/apb_vif/PADDR
add wave -position insertpoint sim:/tb_top/apb_vif/PWRITE
add wave -position insertpoint sim:/tb_top/apb_vif/PWDATA
add wave -position insertpoint sim:/tb_top/apb_vif/PRDATA
add wave -position insertpoint sim:/tb_top/apb_vif/PREADY
add wave -position insertpoint sim:/tb_top/apb_vif/apb_read_data_out
add wave -position insertpoint sim:/tb_top/apb_vif/PSLVERR
# DUT internal FSM state
add wave -position insertpoint sim:/tb_top/dut/state
add wave -position insertpoint sim:/tb_top/dut/next_state

# ---- Run ----
run -all
