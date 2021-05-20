vlib work

vcom -check_synthesis -work work -2002 ../../altera/fifo_32x2048.vhd ../../ethernet/eth_common.vhd ../../ethernet/input_fifo_manager.vhd testbench.vhd 

vsim testbench -t ns

view wave
delete wave *

set ifm_path /testbench/ifm
do ../waveform_files/tb_ifm.do

view objects
view process

layout load Simulate_1

# Eliminates some unset value warnings
set StdArithNoWarnings 1
run 0 ns
set StdArithNoWarnings 0
WaveRestoreZoom {0 ps} {500 ns}
