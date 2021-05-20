onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {TSE} $tse_path/clk
add wave -noupdate -group {TSE} $tse_path/reset
add wave -noupdate -group {TSE} -divider {Config Lines}
add wave -noupdate -group {TSE} $tse_path/readdata
add wave -noupdate -group {TSE} $tse_path/read
add wave -noupdate -group {TSE} $tse_path/writedata
add wave -noupdate -group {TSE} $tse_path/write
add wave -noupdate -group {TSE} $tse_path/waitrequest
add wave -noupdate -group {TSE} $tse_path/address
add wave -noupdate -group {TSE} -divider {Clocks}
add wave -noupdate -group {TSE} $tse_path/ff_rx_clk
add wave -noupdate -group {TSE} $tse_path/ff_tx_clk
#add wave -noupdate -group {TSE} $tse_path/ref_clk
add wave -noupdate -group {TSE} -divider {RX Lines}
add wave -noupdate -group {TSE} -radix hex $tse_path/ff_rx_data
add wave -noupdate -group {TSE} $tse_path/ff_rx_eop
add wave -noupdate -group {TSE} $tse_path/rx_err
add wave -noupdate -group {TSE} $tse_path/ff_rx_mod
add wave -noupdate -group {TSE} $tse_path/ff_rx_rdy
add wave -noupdate -group {TSE} $tse_path/ff_rx_sop
add wave -noupdate -group {TSE} $tse_path/ff_rx_dval
add wave -noupdate -group {TSE} -divider {TX Lines}
add wave -noupdate -group {TSE} -radix hex $tse_path/ff_tx_data
add wave -noupdate -group {TSE} $tse_path/ff_tx_eop
add wave -noupdate -group {TSE} $tse_path/ff_tx_err
add wave -noupdate -group {TSE} $tse_path/ff_tx_mod
add wave -noupdate -group {TSE} $tse_path/ff_tx_rdy
add wave -noupdate -group {TSE} $tse_path/ff_tx_sop
add wave -noupdate -group {TSE} $tse_path/ff_tx_wren
add wave -noupdate -group {TSE} -divider {Misc Lines}
add wave -noupdate -group {TSE} $tse_path/xon_gen
add wave -noupdate -group {TSE} $tse_path/xoff_gen
add wave -noupdate -group {TSE} $tse_path/magic_wakeup
add wave -noupdate -group {TSE} $tse_path/magic_sleep_n
add wave -noupdate -group {TSE} $tse_path/ff_tx_crc_fwd
add wave -noupdate -group {TSE} $tse_path/ff_tx_septy
add wave -noupdate -group {TSE} $tse_path/tx_ff_uflow
add wave -noupdate -group {TSE} $tse_path/ff_tx_a_full
add wave -noupdate -group {TSE} $tse_path/ff_tx_a_empty
add wave -noupdate -group {TSE} $tse_path/rx_err_stat
add wave -noupdate -group {TSE} $tse_path/rx_frm_type
add wave -noupdate -group {TSE} $tse_path/ff_rx_dsav
add wave -noupdate -group {TSE} $tse_path/ff_rx_a_full
add wave -noupdate -group {TSE} $tse_path/ff_rx_a_empty
if {[string first opt $tse_path] != -1 || [string first se $tse_path] != -1} {
	 add wave -noupdate -group {TSE} -divider {LEDs}
	 add wave -noupdate -group {TSE} $tse_path/led_crs
	 add wave -noupdate -group {TSE} $tse_path/led_link
	 add wave -noupdate -group {TSE} $tse_path/led_col
	 add wave -noupdate -group {TSE} $tse_path/led_an
	 add wave -noupdate -group {TSE} $tse_path/led_char_err
	 add wave -noupdate -group {TSE} $tse_path/led_disp_err
}
add wave -noupdate -group {TSE} -divider {Misc}
if {[string first opt $tse_path] != -1} {
	 add wave -noupdate -group {TSE} $tse_path/rx_recovclkout
	 add wave -noupdate -group {TSE} $tse_path/reconfig_togxb
	 add wave -noupdate -group {TSE} $tse_path/reconfig_fromgxb
	 add wave -noupdate -group {TSE} $tse_path/rxp
	 add wave -noupdate -group {TSE} $tse_path/txp
} else {
	 add wave -noupdate -group {TSE} $tse_path/mdc
	 add wave -noupdate -group {TSE} $tse_path/mdio_in
	 add wave -noupdate -group {TSE} $tse_path/mdio_out
	 add wave -noupdate -group {TSE} $tse_path/mdio_oen
	 if {[string first cu $tse_path] != -1} {
	 		add wave -noupdate -group {TSE} $tse_path/tx_clk	 
		add wave -noupdate -group {TSE} $tse_path/rgmii_out
	 add wave -noupdate -group {TSE} $tse_path/tx_control	 
	 add wave -noupdate -group {TSE} $tse_path/rx_clk	 
	 add wave -noupdate -group {TSE} $tse_path/rgmii_in
	 	 add wave -noupdate -group {TSE} $tse_path/rx_control
	}
}