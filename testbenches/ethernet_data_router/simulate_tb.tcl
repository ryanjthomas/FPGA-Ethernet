vlib work
set quartus_directory "/home/ryan/altera/13.0sp1/quartus/bin"

vcom -check_synthesis -work work -2002 ../../ethernet/eth_common.vhd ../../ethernet/ethernet_data_router.vhd testbench.vhd 

vsim testbench -t ns

view wave
delete wave *

config wave -signalnamewidth 1

set erouter_path /testbench/edata_router
do ../waveform_files/tb_erouter.tcl

view objects
view process

layout load Simulate_1


# Eliminates some unset value warnings
set StdArithNoWarnings 1
run 0 ns
set StdArithNoWarnings 0
WaveRestoreZoom {0 ps} {500 ns}
