onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/wrclock
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/rdclock
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/reset
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix hex $udpbuffer/data_in
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/data_valid_in
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix hex $udpbuffer/data_port_in
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/data_rdreq
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/data_eop_in
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/packet_finished
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/data_out
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix hex $udpbuffer/data_port_out
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix unsigned $udpbuffer/payload_len
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/payload_rdy
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/rdempty
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/rdusedw
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/wrfull
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix hex $udpbuffer/info_in
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix hex $udpbuffer/info_out
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/info_rdreq
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/info_wrreq
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/info_empty
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix unsigned $udpbuffer/packet_length_in
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} $udpbuffer/info_valid
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix hex $udpbuffer/previous_udp_port
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix hex $udpbuffer/last_udp_port
add wave -noupdate -group {UDP Data Block} -group {UDP Buffer} -radix unsigned $udpbuffer/last_packet_length
add wave -noupdate -group {UDP Data Block} $udpblock/wrclock
add wave -noupdate -group {UDP Data Block} $udpblock/rdclock
add wave -noupdate -group {UDP Data Block} $udpblock/reset
add wave -noupdate -group {UDP Data Block} $udpblock/data_in
add wave -noupdate -group {UDP Data Block} $udpblock/data_valid_in
add wave -noupdate -group {UDP Data Block} $udpblock/data_port_in
add wave -noupdate -group {UDP Data Block} $udpblock/data_eop_in
add wave -noupdate -group {UDP Data Block} $udpblock/tx_ready
add wave -noupdate -group {UDP Data Block} $udpblock/data_out
add wave -noupdate -group {UDP Data Block} $udpblock/sop
add wave -noupdate -group {UDP Data Block} $udpblock/eop
add wave -noupdate -group {UDP Data Block} $udpblock/dval
add wave -noupdate -group {UDP Data Block} $udpblock/busy
add wave -noupdate -group {UDP Data Block} $udpblock/tx_req
add wave -noupdate -group {UDP Data Block} -radix hex $udpblock/source_mac_addr
add wave -noupdate -group {UDP Data Block} -radix hex $udpblock/dest_mac_addr
add wave -noupdate -group {UDP Data Block} -radix hex $udpblock/source_ip_addr
add wave -noupdate -group {UDP Data Block} -radix hex $udpblock/dest_ip_addr
add wave -noupdate -group {UDP Data Block} -radix hex $udpblock/header_data
add wave -noupdate -group {UDP Data Block} $udpblock/header_valid
add wave -noupdate -group {UDP Data Block} $udpblock/header_done
add wave -noupdate -group {UDP Data Block} $udpblock/header_start
add wave -noupdate -group {UDP Data Block} -radix unsigned $udpblock/fg_payload_len
add wave -noupdate -group {UDP Data Block} $udpblock/fg_data_in
add wave -noupdate -group {UDP Data Block} $udpblock/fg_usedw_in
add wave -noupdate -group {UDP Data Block} $udpblock/fg_payload_rdy
add wave -noupdate -group {UDP Data Block} $udpblock/payload_rdy
add wave -noupdate -group {UDP Data Block} $udpblock/data_rdreq
add wave -noupdate -group {UDP Data Block} $udpblock/wrreq_out
add wave -noupdate -group {UDP Data Block} $udpblock/eop_sig
add wave -noupdate -group {UDP Data Block} $udpblock/frame_length
add wave -noupdate -group {UDP Data Block} $udpblock/frame_rdy
add wave -noupdate -group {UDP Data Block} $udpblock/fg_busy
add wave -noupdate -group {UDP Data Block} $udpblock/payload_max_len
add wave -noupdate -group {UDP Data Block} $udpblock/FIFO_in_dly
add wave -noupdate -group {UDP Data Block} $udpblock/FIFO_out_dly
add wave -noupdate -group {UDP Data Block} -radix unsigned $udpblock/udp_payload_len
add wave -noupdate -group {UDP Data Block} $udpblock/header_len
add wave -noupdate -group {UDP Data Block} $udpblock/source_port
add wave -noupdate -group {UDP Data Block} -radix hex $udpblock/dest_port
add wave -noupdate -group {UDP Data Block} -radix hex $udpblock/data_port_out
