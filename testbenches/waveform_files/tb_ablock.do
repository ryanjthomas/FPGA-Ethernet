onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {ARP Block} $arpblock_path/clock
add wave -noupdate -group {ARP Block} $arpblock_path/reset
add wave -noupdate -group {ARP Block} -divider {Outputs}
add wave -noupdate -group {ARP Block} -radix hex $arpblock_path/data_out
add wave -noupdate -group {ARP Block} $arpblock_path/sop
add wave -noupdate -group {ARP Block} $arpblock_path/eop
add wave -noupdate -group {ARP Block} $arpblock_path/dval
add wave -noupdate -group {ARP Block} $arpblock_path/busy
add wave -noupdate -group {ARP Block} -divider {Inputs}
add wave -noupdate -group {ARP Block} $arpblock_path/tx_ready
add wave -noupdate -group {ARP Block} $arpblock_path/generate_reply
add wave -noupdate -group {ARP Block} -divider {Configuration}
add wave -noupdate -group {ARP Block} -radix hex $arpblock_path/source_mac_addr
add wave -noupdate -group {ARP Block} -radix hex $arpblock_path/dest_mac_addr
add wave -noupdate -group {ARP Block} -radix hex $arpblock_path/source_ip_addr
add wave -noupdate -group {ARP Block} -radix hex $arpblock_path/dest_ip_addr
add wave -noupdate -group {ARP Block} -divider {Internals}
add wave -noupdate -group {ARP Block} $arpblock_path/header_data
add wave -noupdate -group {ARP Block} $arpblock_path/header_valid
add wave -noupdate -group {ARP Block} -radix unsigned $arpblock_path/header_len
add wave -noupdate -group {ARP Block} $arpblock_path/header_done
add wave -noupdate -group {ARP Block} $arpblock_path/header_start
add wave -noupdate -group {ARP Block} -radix unsigned $arpblock_path/payload_len
add wave -noupdate -group {ARP Block} $arpblock_path/usedw_in
add wave -noupdate -group {ARP Block} $arpblock_path/payload_rdy
add wave -noupdate -group {ARP Block} $arpblock_path/rdreq_in
add wave -noupdate -group {ARP Block} $arpblock_path/wrreq_out
add wave -noupdate -group {ARP Block} -radix hex $arpblock_path/frame_length
add wave -noupdate -group {ARP Block} $arpblock_path/frame_rdy
add wave -noupdate -group {ARP Block} $arpblock_path/fg_busy
add wave -noupdate -group {ARP Block} -radix hex $arpblock_path/fg_data_in
add wave -noupdate -group {ARP Block} -radix hex $arpblock_path/arp_data_out
add wave -noupdate -group {ARP Block} $arpblock_path/arp_dval
add wave -noupdate -group {ARP Block} $arpblock_path/start_reply
add wave -noupdate -group {ARP Block} $arpblock_path/end_reply
add wave -noupdate -group {ARP Block} $arpblock_path/dest_mac_addr_reg
add wave -noupdate -group {ARP Block} $arpblock_path/dest_ip_addr_reg
add wave -noupdate -group {ARP Block} $arpblock_path/reply_wait
