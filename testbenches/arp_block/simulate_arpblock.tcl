vlib work
vcom -check_synthesis -work work -2002  ../../ethernet/eth_common.vhd  ../../ethernet/header_generator.vhd ../../ethernet/ethernet_frame_generator.vhd ../../ethernet/arp_replier.vhd ../../ethernet/arp_block.vhd testbench.vhd

vsim testbench -t ns

view wave
delete wave *

config wave -signalnamewidth 1

set hdgen_path /testbench/arpblock/hdgen
set fg_path /testbench/arpblock/fg
set arpreply_path /testbench/arpblock/arpgen
do ../waveform_files/tb_hdgen.do
do ../waveform_files/tb_fg.do
do ../waveform_files/tb_arpreply.do

view objects
view process

layout load Simulate_1


# Eliminates some unset value warnings
set StdArithNoWarnings 1
run 0 ns
set StdArithNoWarnings 0
WaveRestoreZoom {0 ps} {500 ns}
