vlib work
vcom -check_synthesis -work work -2002 ../../ethernet/eth_common.vhd  ../../ethernet/header_generator.vhd  testbench.vhd

vsim testbench -t ns

view wave
delete wave *

set hdgen_path /testbench/hdgen
do ../waveform_files/tb_hdgen.do

view objects
view process

layout load Simulate_1


# Eliminates some unset value warnings
set StdArithNoWarnings 1
run 0 ns
set StdArithNoWarnings 0
WaveRestoreZoom {0 ps} {500 ns}
