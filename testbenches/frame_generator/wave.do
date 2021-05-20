onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {Header Generator} -label Clock /testbench/hdgen/clock
add wave -noupdate -group {Header Generator} -label Reset /testbench/hdgen/reset
add wave -noupdate -group {Header Generator} -label {Header data} -radix hexadecimal /testbench/hdgen/header_data
add wave -noupdate -group {Header Generator} -label {Header valid} /testbench/hdgen/header_valid
add wave -noupdate -group {Header Generator} -label {Header len} -radix unsigned /testbench/hdgen/header_len
add wave -noupdate -group {Header Generator} -label {Header done} /testbench/hdgen/header_done
add wave -noupdate -group {Header Generator} -label {header start} /testbench/hdgen/header_start
add wave -noupdate -group {Header Generator} -label protocol -radix hexadecimal /testbench/hdgen/protocol
add wave -noupdate -group {Header Generator} -label {app header} -radix hexadecimal /testbench/hdgen/app_header
add wave -noupdate -group {Header Generator} -label {payload len} -radix unsigned /testbench/hdgen/payload_len
add wave -noupdate -group {Header Generator} -label {packet len} -radix decimal /testbench/hdgen/packet_len
add wave -noupdate -group {Header Generator} -label {source mac address} -radix hexadecimal /testbench/hdgen/source_mac_addr
add wave -noupdate -group {Header Generator} -label {destination mac address} -radix hexadecimal /testbench/hdgen/dest_mac_addr
add wave -noupdate -group {Header Generator} -label {source IP} -radix hexadecimal /testbench/hdgen/source_ip
add wave -noupdate -group {Header Generator} -label {destination IP} -radix hexadecimal /testbench/hdgen/dest_ip
add wave -noupdate -group {Header Generator} -label {source port} -radix unsigned /testbench/hdgen/source_port
add wave -noupdate -group {Header Generator} -label {destination port} -radix unsigned /testbench/hdgen/dest_port
add wave -noupdate -group {Header Generator} -label state /testbench/hdgen/state
add wave -noupdate -group {Header Generator} -label {next state} /testbench/hdgen/next_state
add wave -noupdate -group {Header Generator} -label {IPv4 checksum} -radix binary /testbench/hdgen/ip_checksum
add wave -noupdate -expand -group {Frame Generator} -label Clock /testbench/frame_gen/clock
add wave -noupdate -expand -group {Frame Generator} -label reset /testbench/frame_gen/reset
add wave -noupdate -expand -group {Frame Generator} -group Header -label {Header data} -radix hexadecimal /testbench/frame_gen/header_data
add wave -noupdate -expand -group {Frame Generator} -group Header -label {Header valid} /testbench/frame_gen/header_valid
add wave -noupdate -expand -group {Frame Generator} -group Header -label {Header done} /testbench/frame_gen/header_done
add wave -noupdate -expand -group {Frame Generator} -group Header -label {Header start} /testbench/frame_gen/header_start
add wave -noupdate -expand -group {Frame Generator} -label {Payload len} -radix unsigned /testbench/frame_gen/payload_len
add wave -noupdate -expand -group {Frame Generator} -label {Data in} -radix unsigned /testbench/frame_gen/data_in
add wave -noupdate -expand -group {Frame Generator} -label {Used words in} -radix unsigned /testbench/frame_gen/usedw_in
add wave -noupdate -expand -group {Frame Generator} -label {Payload read} /testbench/frame_gen/payload_rdy
add wave -noupdate -expand -group {Frame Generator} -label {In FIFO read rq} /testbench/frame_gen/rdreq_in
add wave -noupdate -expand -group {Frame Generator} -label {Data out} -radix hexadecimal /testbench/frame_gen/data_out
add wave -noupdate -expand -group {Frame Generator} -label {Out FIFO write rq} /testbench/frame_gen/wrreq_out
add wave -noupdate -expand -group {Frame Generator} -label {SoP Strobe} /testbench/frame_gen/sop
add wave -noupdate -expand -group {Frame Generator} -label {EoP Strobe} /testbench/frame_gen/eop
add wave -noupdate -expand -group {Frame Generator} -label {FG busy} /testbench/frame_gen/fg_busy
add wave -noupdate -expand -group {Frame Generator} -label {Frame Length} -radix unsigned /testbench/frame_gen/frame_length
add wave -noupdate -expand -group {Frame Generator} -label {Frame rdy strobe} /testbench/frame_gen/frame_rdy
add wave -noupdate -expand -group {Frame Generator} -label {Max Payload len} /testbench/frame_gen/payload_max_len
add wave -noupdate -expand -group {Frame Generator} -label {In FIFO dly} -radix unsigned /testbench/frame_gen/FIFO_in_dly
add wave -noupdate -expand -group {Frame Generator} -label {Out FIFO dly} -radix unsigned /testbench/frame_gen/FIFO_out_dly
add wave -noupdate -expand -group {Frame Generator} -label {FG State} /testbench/frame_gen/state
add wave -noupdate -expand -group {Frame Generator} -label {FG Next state} /testbench/frame_gen/next_state
add wave -noupdate -expand -group {Frame Generator} -label {Frame word} -radix hexadecimal /testbench/frame_gen/frame_word
add wave -noupdate -expand -group {Frame Generator} -label {Payload word} -radix hexadecimal /testbench/frame_gen/payload_word
add wave -noupdate -expand -group {Frame Generator} -label {Payload len sig} /testbench/frame_gen/payload_length
add wave -noupdate -expand -group {Frame Generator} -group {New Group} /testbench/frame_gen/CRC32GenD32_1/Clk
add wave -noupdate -expand -group {Frame Generator} -group {New Group} /testbench/frame_gen/CRC32GenD32_1/Clr_CRC
add wave -noupdate -expand -group {Frame Generator} -group {New Group} /testbench/frame_gen/CRC32GenD32_1/Din
add wave -noupdate -expand -group {Frame Generator} -group {New Group} /testbench/frame_gen/CRC32GenD32_1/CRC
add wave -noupdate -expand -group {Frame Generator} -group {New Group} /testbench/frame_gen/CRC32GenD32_1/Calc
add wave -noupdate -expand -group {Frame Generator} -label {Generate CRC} /testbench/frame_gen/gen_crc
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2863 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
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
WaveRestoreZoom {2788 ns} {2914 ns}
