onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {Frame Reciever} $fr_path/rd_clk
add wave -noupdate -group {Frame Reciever} $fr_path/reset
add wave -noupdate -group {Frame Reciever} -divider {Outputs}
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/data_out
add wave -noupdate -group {Frame Reciever} $fr_path/dval
add wave -noupdate -group {Frame Reciever} $fr_path/eop
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/source_mac_addr
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/dest_mac_addr
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/source_ip_addr
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/dest_ip_addr
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/source_port
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/dest_port
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/ethertype
add wave -noupdate -group {Frame Reciever} $fr_path/generate_arp_reply
add wave -noupdate -group {Frame Reciever} -radix hex $fr_path/ip_protocol
add wave -noupdate -group {Frame Reciever} $fr_path/icmp_ping
add wave -noupdate -group {Frame Reciever} -radix unsigned $fr_path/packet_length
add wave -noupdate -group {Frame Reciever} -divider {TSE RX}
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/rx_data
add wave -noupdate -group {Frame Reciever} $fr_path/rx_eop
add wave -noupdate -group {Frame Reciever} $fr_path/rx_err
add wave -noupdate -group {Frame Reciever} $fr_path/rx_mod
add wave -noupdate -group {Frame Reciever} $fr_path/rx_rdy
add wave -noupdate -group {Frame Reciever} $fr_path/rx_sop
add wave -noupdate -group {Frame Reciever} $fr_path/rx_dval
add wave -noupdate -group {Frame Reciever} -divider {Configuration}
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/our_ip_addr
add wave -noupdate -group {Frame Reciever} -divider {Internals}
add wave -noupdate -group {Frame Reciever} -radix hexadecimal $fr_path/frame_word
add wave -noupdate -group {Frame Reciever} $fr_path/word_num
add wave -noupdate -group {Frame Reciever} $fr_path/data_valid
add wave -noupdate -group {Frame Reciever} $fr_path/rdy_sig
add wave -noupdate -group {Frame Reciever} $fr_path/payload_len
