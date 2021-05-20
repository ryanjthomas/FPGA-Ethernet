onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {ARP Replier} $arpreply_path/clock
add wave -noupdate -group {ARP Replier} $arpreply_path/reset
add wave -noupdate -group {ARP Replier} -radix hex $arpreply_path/data_out
add wave -noupdate -group {ARP Replier} $arpreply_path/dval
add wave -noupdate -group {ARP Replier} -radix hex $arpreply_path/source_mac_addr
add wave -noupdate -group {ARP Replier} -radix hex $arpreply_path/dest_mac_addr
add wave -noupdate -group {ARP Replier} -radix hex $arpreply_path/source_ip_addr
add wave -noupdate -group {ARP Replier} -radix hex $arpreply_path/dest_ip_addr
add wave -noupdate -group {ARP Replier} $arpreply_path/start_reply
add wave -noupdate -group {ARP Replier} $arpreply_path/end_reply
#add wave -noupdate -group {ARP Replier} $arpreply_path/state
add wave -noupdate -group {ARP Replier} $arpreply_path/next_state
