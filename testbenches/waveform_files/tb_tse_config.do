onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group TSE_config $tse_config_path/clock
add wave -noupdate -group TSE_config $tse_config_path/reset
add wave -noupdate -group TSE_config $tse_config_path/mac_sw_reset
add wave -noupdate -group TSE_config $tse_config_path/reconfig
add wave -noupdate -group TSE_config -divider {TSE Lines}
add wave -noupdate -group TSE_config -radix hex $tse_config_path/readdata
add wave -noupdate -group TSE_config $tse_config_path/read_req
add wave -noupdate -group TSE_config -radix hex $tse_config_path/writedata
add wave -noupdate -group TSE_config $tse_config_path/write_req
add wave -noupdate -group TSE_config $tse_config_path/waitrequest
add wave -noupdate -group TSE_config -radix hex $tse_config_path/address
add wave -noupdate -group TSE_config -divider {Configuration}
add wave -noupdate -group TSE_config $tse_config_path/config
add wave -noupdate -group TSE_config -radix hex $tse_config_path/mac_addr
add wave -noupdate -group TSE_config -divider {Output Status}
add wave -noupdate -group TSE_config $tse_config_path/mac_ready
add wave -noupdate -group TSE_config $tse_config_path/mac_error
add wave -noupdate -group TSE_config -divider {Internals}
add wave -noupdate -group TSE_config $tse_config_path/pcs_command_word
add wave -noupdate -group TSE_config $tse_config_path/pcs_reset_word
add wave -noupdate -group TSE_config $tse_config_path/reconfig_sig
add wave -noupdate -group TSE_config $tse_config_path/state
add wave -noupdate -group TSE_config $tse_config_path/next_state
add wave -noupdate -group TSE_config $tse_config_path/read_data_sig
add wave -noupdate -group TSE_config $tse_config_path/write_data_sig
add wave -noupdate -group TSE_config $tse_config_path/address_sig
add wave -noupdate -group TSE_config $tse_config_path/read_req_sig
add wave -noupdate -group TSE_config $tse_config_path/write_req_sig
add wave -noupdate -group TSE_config $tse_config_path/mac_ready_sig
add wave -noupdate -group TSE_config $tse_config_path/mac_error_sig
add wave -noupdate -group TSE_config $tse_config_path/state_machine_reset
add wave -noupdate -group TSE_config $tse_config_path/state_machine_error
add wave -noupdate -group TSE_config $tse_config_path/do_sw_reset
add wave -noupdate -group TSE_config $tse_config_path/no_lgth_check
add wave -noupdate -group TSE_config $tse_config_path/xoff_gen
add wave -noupdate -group TSE_config $tse_config_path/sleep
add wave -noupdate -group TSE_config $tse_config_path/magic_ena
add wave -noupdate -group TSE_config $tse_config_path/loop_ena
add wave -noupdate -group TSE_config $tse_config_path/excess_col
add wave -noupdate -group TSE_config $tse_config_path/late_col
add wave -noupdate -group TSE_config $tse_config_path/hd_ena
add wave -noupdate -group TSE_config $tse_config_path/tx_addr_ins
add wave -noupdate -group TSE_config $tse_config_path/promis_en
add wave -noupdate -group TSE_config $tse_config_path/xon_gen
add wave -noupdate -group TSE_config $tse_config_path/enable_AN
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 169
configure wave -valuecolwidth 100
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
WaveRestoreZoom {0 ns} {487 ns}
