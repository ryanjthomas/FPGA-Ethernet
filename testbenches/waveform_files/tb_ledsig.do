onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate $led_path/clock
add wave -noupdate $led_path/led_link_out
add wave -noupdate $led_path/led_act_out
add wave -noupdate $led_path/led_combined_out
add wave -noupdate $led_path/led2_link
add wave -noupdate $led_path/led1_link
add wave -noupdate $led_path/led0_link
add wave -noupdate $led_path/led2_act
add wave -noupdate $led_path/led1_act
add wave -noupdate $led_path/led0_act
add wave -noupdate $led_path/led_act
add wave -noupdate $led_path/led_link
add wave -noupdate $led_path/led_act_out_sig
