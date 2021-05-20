vlib work
set quartus_directory "/home/ryan/altera/13.0sp1/quartus/bin"

set TOP_LEVEL_NAME testbench
set QSYS_SIMDIR ../../tse_sgmii/tse_sgmii_sim
source $QSYS_SIMDIR/mentor/msim_setup.tcl
#Only need to run once
com

vcom -check_synthesis -work work -2002 ../../altera/mdio_buffer.vhd mdio_reg.vhd mdio_slave.vhd top_mdio_slave.vhd  ../../altera/fifo_32x2048.vhd ../../altera/fifo_32x256.vhd ../../altera/scfifo_sa_32x16.vhd ../../ethernet/eth_common.vhd ../../common_modules/reset_controller.vhd ../../ethernet/input_fifo_manager.vhd ../../ethernet/header_generator.vhd ../../ethernet/ethernet_frame_generator.vhd ../../ethernet/ethernet_data_block.vhd ../../ethernet/ethernet_frame_reciever.vhd ../../common_modules/config_register_block.vhd ../../ethernet/udp_data_buffer.vhd ../../ethernet/udp_data_block.vhd ../../ethernet/arp_cache.vhd ../../ethernet/tse_config_controller.vhd ../../ethernet/arp_replier.vhd ../../ethernet/arp_block.vhd ../../ethernet/icmp_block.vhd  ../../ethernet/ethernet_block.vhd ../../ethernet/ethernet_sgmii_block.vhd testbench.vhd 

#vsim testbench -t ns
elab_debug

view wave
delete wave *

config wave -signalnamewidth 1

set fg_path /testbench/seblock/eblock/datablock/fg
set hdgen_path /testbench/seblock/eblock/datablock/hdgen
set ifm_path /testbench/seblock/eblock/datablock/ifm
set tse_path /testbench/seblock/tse
set tse_config_path /testbench/seblock/eblock/tse_config
set fr_path /testbench/seblock/eblock/reciever
set arpblock_path /testbench/seblock/eblock/arpblock
set icmpblock_path /testbench/seblock/eblock/icmpblock
set configblock_path /testbench/seblock/eblock/configblock
set rcon_path $tse_config_path/reset_controller_1
do ../waveform_files/tb_hdgen.do
do ../waveform_files/tb_fg.do
do ../waveform_files/tb_ifm.do
do ../waveform_files/tb_tse.do
do ../waveform_files/tb_tse_config.do
do ../waveform_files/tb_fr.do
do ../waveform_files/tb_ablock.do
do ../waveform_files/tb_icmpblock.do
do ../waveform_files/tb_configblock.do
do ../waveform_files/tb_rcon.do

view objects
view process

layout load Simulate_1


# Eliminates some unset value warnings
set StdArithNoWarnings 1
run 0 ns
set StdArithNoWarnings 0
WaveRestoreZoom {0 ps} {500 ns}
