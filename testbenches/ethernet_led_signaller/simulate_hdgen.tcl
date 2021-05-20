vlib work
vcom -check_synthesis -work work -2002 ../../ethernet/eth_common.vhd  ../../ethernet/ethernet_led_signaler.vhd  testbench.vhd

vsim testbench -t ns

view wave
delete wave *

config wave -signalnamewidth 1

set led_path /testbench/ledsig
do ../waveform_files/tb_ledsig.do

view objects
view process

layout load Simulate_1


# Eliminates some unset value warnings
set StdArithNoWarnings 1
run 0 ns
set StdArithNoWarnings 0
WaveRestoreZoom {0 ps} {100 us}
