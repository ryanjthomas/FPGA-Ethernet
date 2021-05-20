onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {Ethernet Data Router} $erouter_path/clock
add wave -noupdate -group {Ethernet Data Router} $erouter_path/reset
add wave -noupdate -group {Ethernet Data Router} -divider Inputs
add wave -noupdate -group {Ethernet Data Router} -radix hexadecimal $erouter_path/data_in0
add wave -noupdate -group {Ethernet Data Router} $erouter_path/data_valid0
add wave -noupdate -group {Ethernet Data Router} $erouter_path/data_port0
add wave -noupdate -group {Ethernet Data Router} -radix hexadecimal $erouter_path/data_in1
add wave -noupdate -group {Ethernet Data Router} $erouter_path/data_valid1
add wave -noupdate -group {Ethernet Data Router} $erouter_path/data_port1
add wave -noupdate -group {Ethernet Data Router} -radix hexadecimal $erouter_path/data_in2
add wave -noupdate -group {Ethernet Data Router} $erouter_path/data_valid2
add wave -noupdate -group {Ethernet Data Router} $erouter_path/data_port2
add wave -noupdate -group {Ethernet Data Router} -divider Outputs
add wave -noupdate -group {Ethernet Data Router} -radix hexadecimal $erouter_path/config_data_out
add wave -noupdate -group {Ethernet Data Router} $erouter_path/config_valid
add wave -noupdate -group {Ethernet Data Router} -radix hexadecimal $erouter_path/loopback_data0
add wave -noupdate -group {Ethernet Data Router} $erouter_path/loopback_wrreq0
add wave -noupdate -group {Ethernet Data Router} -radix hexadecimal $erouter_path/loopback_data1
add wave -noupdate -group {Ethernet Data Router} $erouter_path/loopback_wrreq1
add wave -noupdate -group {Ethernet Data Router} -radix hexadecimal $erouter_path/loopback_data2
add wave -noupdate -group {Ethernet Data Router} $erouter_path/loopback_wrreq2
add wave -noupdate -group {Ethernet Data Router} -divider Internals
add wave -noupdate -group {Ethernet Data Router} $erouter_path/loopback_data
add wave -noupdate -group {Ethernet Data Router} $erouter_path/loopback_wrreqs
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}

