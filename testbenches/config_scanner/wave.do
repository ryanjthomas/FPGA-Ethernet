onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/config_block_scanner_1/clock
add wave -noupdate /testbench/config_block_scanner_1/reset
add wave -noupdate -radix hexadecimal /testbench/config_block_scanner_1/config_data_in
add wave -noupdate /testbench/config_block_scanner_1/config_valid_in
add wave -noupdate -radix hexadecimal /testbench/config_block_scanner_1/config_data_out
add wave -noupdate /testbench/config_block_scanner_1/config_valid_out
add wave -noupdate -radix hexadecimal -childformat {{/testbench/config_block_scanner_1/udp_out_bus(52) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(51) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(50) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(49) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(48) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(47) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(46) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(45) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(44) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(43) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(42) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(41) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(40) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(39) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(38) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(37) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(36) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(35) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(34) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(33) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(32) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(31) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(30) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(29) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(28) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(27) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(26) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(25) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(24) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(23) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(22) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(21) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(20) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(19) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(18) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(17) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(16) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(15) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(14) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(13) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(12) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(11) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(10) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(9) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(8) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(7) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(6) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(5) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(4) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(3) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(2) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(1) -radix hexadecimal} {/testbench/config_block_scanner_1/udp_out_bus(0) -radix hexadecimal}} -subitemconfig {/testbench/config_block_scanner_1/udp_out_bus(52) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(51) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(50) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(49) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(48) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(47) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(46) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(45) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(44) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(43) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(42) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(41) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(40) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(39) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(38) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(37) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(36) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(35) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(34) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(33) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(32) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(31) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(30) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(29) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(28) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(27) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(26) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(25) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(24) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(23) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(22) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(21) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(20) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(19) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(18) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(17) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(16) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(15) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(14) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(13) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(12) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(11) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(10) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(9) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(8) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(7) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(6) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(5) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(4) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(3) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(2) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(1) {-radix hexadecimal} /testbench/config_block_scanner_1/udp_out_bus(0) {-radix hexadecimal}} /testbench/config_block_scanner_1/udp_out_bus
add wave -noupdate /testbench/config_block_scanner_1/udp_ready
add wave -noupdate /testbench/config_block_scanner_1/start_scan_blocks
add wave -noupdate /testbench/config_block_scanner_1/scan_finished
add wave -noupdate /testbench/config_block_scanner_1/start_scan_single
add wave -noupdate /testbench/config_block_scanner_1/start_block_address
add wave -noupdate /testbench/config_block_scanner_1/busy
add wave -noupdate /testbench/config_block_scanner_1/next_state
add wave -noupdate /testbench/config_block_scanner_1/toread_block_addr
add wave -noupdate -radix hexadecimal /testbench/config_block_scanner_1/config_data_out_reg
add wave -noupdate /testbench/config_block_scanner_1/config_valid_out_reg
add wave -noupdate -radix hexadecimal /testbench/config_block_scanner_1/config_data_in_reg
add wave -noupdate /testbench/config_block_scanner_1/config_valid_in_reg
add wave -noupdate -radix hexadecimal /testbench/config_block_scanner_1/curr_reg_addr
add wave -noupdate -radix hexadecimal /testbench/config_block_scanner_1/curr_block_addr
add wave -noupdate -radix hexadecimal /testbench/config_block_scanner_1/data_out
add wave -noupdate /testbench/config_block_scanner_1/data_out_valid
add wave -noupdate /testbench/config_block_scanner_1/data_out_eop
add wave -noupdate /testbench/config_block_scanner_1/tx_req
add wave -noupdate /testbench/config_block_scanner_1/tx_busy
add wave -noupdate -group {Config Multiplexer} /testbench/config_read_multiplexer_1/clock
add wave -noupdate -group {Config Multiplexer} /testbench/config_read_multiplexer_1/config_data_in
add wave -noupdate -group {Config Multiplexer} /testbench/config_read_multiplexer_1/config_valid_in
add wave -noupdate -group {Config Multiplexer} /testbench/config_read_multiplexer_1/config_data_out
add wave -noupdate -group {Config Multiplexer} /testbench/config_read_multiplexer_1/config_valid_out
add wave -noupdate -group {Config Multiplexer} /testbench/config_read_multiplexer_1/config_data_out_reg
add wave -noupdate -group {Config Multiplexer} /testbench/config_read_multiplexer_1/config_valid_out_reg
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/clock
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/reset
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/udp_data_out
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/udp_port_out
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/udp_valid_out
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/udp_eop_out
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/udp_in_bus_cmd
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/udp_ready_cmd
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/udp_in_bus_ccdint
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/udp_ready_ccdint
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/udp_in_bus_scan
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/udp_ready_scan
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/udp_tx_busy
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/tx_req_cmd
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/tx_req_ccdint
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/tx_busy_cmd
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/tx_busy_ccdint
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/data_cmd
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/data_ccdint
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/port_cmd
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/port_ccdint
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/valid_cmd
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/valid_ccdint
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/eop_cmd
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/eop_ccdint
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/client_busy
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/client_dval
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/client_eop
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/tx_req_scan
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/tx_busy_scan
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/data_scan
add wave -noupdate -group {UDP Data Arbiter} -radix hexadecimal /testbench/udp_data_arbiter_1/port_scan
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/valid_scan
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/eop_scan
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/next_state
add wave -noupdate -group {UDP Data Arbiter} /testbench/udp_data_arbiter_1/current_client
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 223
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {8917 ns}
