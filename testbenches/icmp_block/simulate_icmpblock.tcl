vlib work
vcom -check_synthesis -work work -2002  ../../altera/fifo_32x256.vhd ../../ethernet/eth_common.vhd  ../../ethernet/header_generator.vhd ../../ethernet/ethernet_frame_generator.vhd ../../ethernet/icmp_block.vhd testbench.vhd

vsim testbench -t ns

view wave
delete wave *

config wave -signalnamewidth 1

set hdgen_path /testbench/icmpblock/hdgen
set fg_path /testbench/icmpblock/fg
set icmpblock_path /testbench/icmpblock
do ../waveform_files/tb_hdgen.do
do ../waveform_files/tb_fg.do
do ../waveform_files/tb_icmpblock.do

view objects
view process

layout load Simulate_1


# Eliminates some unset value warnings
set StdArithNoWarnings 1
run 0 ns
set StdArithNoWarnings 0
WaveRestoreZoom {0 ps} {500 ns}
