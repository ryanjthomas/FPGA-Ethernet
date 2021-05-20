onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {ICMP Block} $icmpblock_path/clock
add wave -noupdate -group {ICMP Block} $icmpblock_path/reset
add wave -noupdate -group {ICMP Block} -divider {Outputs}
add wave -noupdate -group {ICMP Block} -radix hex $icmpblock_path/data_out
add wave -noupdate -group {ICMP Block} $icmpblock_path/sop
add wave -noupdate -group {ICMP Block} $icmpblock_path/eop
add wave -noupdate -group {ICMP Block} $icmpblock_path/dval
add wave -noupdate -group {ICMP Block} $icmpblock_path/busy
add wave -noupdate -group {ICMP Block} -divider {Inputs}
add wave -noupdate -group {ICMP Block} -radix hex $icmpblock_path/fr_data_out
add wave -noupdate -group {ICMP Block} $icmpblock_path/fr_dval
add wave -noupdate -group {ICMP Block} $icmpblock_path/fr_eop
add wave -noupdate -group {ICMP Block} $icmpblock_path/icmp_ping
add wave -noupdate -group {ICMP Block} $icmpblock_path/tx_ready
add wave -noupdate -group {ICMP Block} -divider {Configuration}
add wave -noupdate -group {ICMP Block} -radix hex $icmpblock_path/source_mac_addr
add wave -noupdate -group {ICMP Block} -radix hex $icmpblock_path/dest_mac_addr
add wave -noupdate -group {ICMP Block} -radix hex $icmpblock_path/source_ip_addr
add wave -noupdate -group {ICMP Block} -radix hex $icmpblock_path/dest_ip_addr
add wave -noupdate -group {ICMP Block} -divider {Internals}
add wave -noupdate -group {ICMP Block} -radix hex $icmpblock_path/header_data
add wave -noupdate -group {ICMP Block} $icmpblock_path/header_valid
add wave -noupdate -group {ICMP Block} -radix unsigned $icmpblock_path/header_len
add wave -noupdate -group {ICMP Block} $icmpblock_path/header_done
add wave -noupdate -group {ICMP Block} $icmpblock_path/header_start
add wave -noupdate -group {ICMP Block} $icmpblock_path/payload_len
add wave -noupdate -group {ICMP Block} $icmpblock_path/fg_data_in
add wave -noupdate -group {ICMP Block} $icmpblock_path/usedw_in
add wave -noupdate -group {ICMP Block} $icmpblock_path/payload_rdy
add wave -noupdate -group {ICMP Block} $icmpblock_path/rdreq_in
add wave -noupdate -group {ICMP Block} $icmpblock_path/wrreq_out
add wave -noupdate -group {ICMP Block} $icmpblock_path/frame_length
add wave -noupdate -group {ICMP Block} $icmpblock_path/frame_rdy
add wave -noupdate -group {ICMP Block} $icmpblock_path/fg_busy
add wave -noupdate -group {ICMP Block} $icmpblock_path/fifo_rdreq
add wave -noupdate -group {ICMP Block} $icmpblock_path/fifo_wrreq
add wave -noupdate -group {ICMP Block} $icmpblock_path/fifo_empty
add wave -noupdate -group {ICMP Block} $icmpblock_path/fifo_full
add wave -noupdate -group {ICMP Block} $icmpblock_path/fifo_q
add wave -noupdate -group {ICMP Block} $icmpblock_path/fifo_usedw
add wave -noupdate -group {ICMP Block} $icmpblock_path/fr_eop_delayed
add wave -noupdate -group {ICMP Block} $icmpblock_path/icmp_ping_delayed
add wave -noupdate -group {ICMP Block} -radix hex $icmpblock_path/checksum
add wave -noupdate -group {ICMP Block} $icmpblock_path/checksum_valid
add wave -noupdate -group {ICMP Block} $icmpblock_path/dest_mac_addr_reg
add wave -noupdate -group {ICMP Block} $icmpblock_path/dest_ip_addr_reg
add wave -noupdate -group {ICMP Block} $icmpblock_path/reply_wait
