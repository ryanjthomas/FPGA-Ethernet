onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {Ethernet Config Block} $configblock_path/BLOCK_ADDRESS
add wave -noupdate -group {Ethernet Config Block} $configblock_path/clock
add wave -noupdate -group {Ethernet Config Block} $configblock_path/reset
add wave -noupdate -group {Ethernet Config Block} -radix hexadecimal $configblock_path/config_data_in
add wave -noupdate -group {Ethernet Config Block} $configblock_path/config_valid_in
add wave -noupdate -group {Ethernet Config Block} -radix hexadecimal $configblock_path/config_data_out
add wave -noupdate -group {Ethernet Config Block} $configblock_path/config_valid_out
add wave -noupdate -group {Ethernet Config Block} -radix hexadecimal $configblock_path/config_registers
add wave -noupdate -group {Ethernet Config Block} $configblock_path/config_changed
add wave -noupdate -group {Ethernet Config Block} $configblock_path/config_error
add wave -noupdate -group {Ethernet Config Block} $configblock_path/config_registers_reg
add wave -noupdate -group {Ethernet Config Block} $configblock_path/config_changed_regs
add wave -noupdate -group {Ethernet Config Block} $configblock_path/reconfiged
add wave -noupdate -group {Ethernet Config Block} $configblock_path/block_read_index
add wave -noupdate -group {Ethernet Config Block} $configblock_path/write_error
add wave -noupdate -group {Ethernet Config Block} $configblock_path/read_error

