vlib work
vcom -check_synthesis -work work -2002  ../../altera/fifo_32x2048.vhd ../../ethernet/eth_common.vhd ../../ethernet/input_fifo_manager.vhd ../../ethernet/header_generator.vhd ../../ethernet/ethernet_frame_generator.vhd ../../ethernet/ethernet_data_block.vhd testbench.vhd 

vsim testbench -t ns

view wave
delete wave *

set fg_path /eblock/fg
set hdgen_path /eblock/hdgen
set ifm_path /eblock/ifm
do ../waveform_files/tb_hdgen.do
do ../waveform_files/tb_fg.do
do ../waveform_files/tb_ifm.do

view objects
view process

layout load Simulate_1


# Eliminates some unset value warnings
set StdArithNoWarnings 1
run 0 ns
set StdArithNoWarnings 0
WaveRestoreZoom {0 ps} {500 ns}
