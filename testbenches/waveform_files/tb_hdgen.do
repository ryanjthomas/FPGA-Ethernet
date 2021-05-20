onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {Header Generator} -label Clock $hdgen_path/clock
add wave -noupdate -group {Header Generator} -label Reset $hdgen_path/reset
add wave -noupdate -group {Header Generator} -label {Header data} -radix hexadecimal $hdgen_path/header_data
add wave -noupdate -group {Header Generator} -label {Header valid} $hdgen_path/header_valid
add wave -noupdate -group {Header Generator} -label {Header len} -radix unsigned $hdgen_path/header_len
add wave -noupdate -group {Header Generator} -label {Header done} $hdgen_path/header_done
add wave -noupdate -group {Header Generator} -label {header start} $hdgen_path/header_start
add wave -noupdate -group {Header Generator} -label protocol -radix hexadecimal $hdgen_path/protocol
add wave -noupdate -group {Header Generator} -label {app header} -radix hexadecimal $hdgen_path/app_header
add wave -noupdate -group {Header Generator} -label {payload len} -radix unsigned $hdgen_path/payload_len
add wave -noupdate -group {Header Generator} -label {packet len} -radix decimal $hdgen_path/packet_len
add wave -noupdate -group {Header Generator} -label {source mac address} -radix hexadecimal $hdgen_path/source_mac_addr
add wave -noupdate -group {Header Generator} -label {destination mac address} -radix hexadecimal $hdgen_path/dest_mac_addr
add wave -noupdate -group {Header Generator} -label {source IP} -radix hexadecimal $hdgen_path/source_ip
add wave -noupdate -group {Header Generator} -label {destination IP} -radix hexadecimal $hdgen_path/dest_ip
add wave -noupdate -group {Header Generator} -label {source port} -radix unsigned $hdgen_path/source_port
add wave -noupdate -group {Header Generator} -label {destination port} -radix unsigned $hdgen_path/dest_port
add wave -noupdate -group {Header Generator} -label state $hdgen_path/state
add wave -noupdate -group {Header Generator} -label {next state} $hdgen_path/next_state
add wave -noupdate -group {Header Generator} -label {IPv4 checksum} -radix binary $hdgen_path/ip_checksum

update
