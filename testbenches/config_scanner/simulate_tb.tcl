vlib work
vcom -check_synthesis -work work -2002 ../../common_modules/config_register_block.vhd ../../ethernet/eth_common.vhd ../../ethernet/udp_data_arbiter.vhd ../../config_scanner/config_read_multiplexer.vhd ../../config_scanner/config_block_scanner.vhd testbench.vhd

vsim testbench -t ns

view wave
delete wave *

config wave -signalnamewidth 1

do wave.do

view objects
view process

layout load Simulate_1



# Eliminates some unset value warnings
set StdArithNoWarnings 1
run 0 ns
set StdArithNoWarnings 0
WaveRestoreZoom {0 ps} {10 us}
