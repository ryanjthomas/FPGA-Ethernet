onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {Frame Generator} -label Clock $fg_path/clock
add wave -noupdate -group {Frame Generator} -label reset $fg_path/reset
add wave -noupdate -group {Frame Generator} -group {Header} -label {Header data} -radix hexadecimal $fg_path/header_data
add wave -noupdate -group {Frame Generator} -group {Header} -label {Header valid} $fg_path/header_valid
add wave -noupdate -group {Frame Generator} -group {Header} -label {Header done} $fg_path/header_done
add wave -noupdate -group {Frame Generator} -group {Header} -label {Header start} $fg_path/header_start
add wave -noupdate -group {Frame Generator} -label {Payload len} -radix unsigned $fg_path/payload_len
add wave -noupdate -group {Frame Generator} -label {Data in} -radix unsigned $fg_path/data_in
add wave -noupdate -group {Frame Generator} -label {Used words in} -radix unsigned $fg_path/usedw_in
add wave -noupdate -group {Frame Generator} -label {Payload read} $fg_path/payload_rdy
add wave -noupdate -group {Frame Generator} -label {In FIFO read rq} $fg_path/rdreq_in
add wave -noupdate -group {Frame Generator} -label {Data out} -radix hex $fg_path/data_out
add wave -noupdate -group {Frame Generator} -label {Out FIFO write rq} $fg_path/wrreq_out
add wave -noupdate -group {Frame Generator} -label {SoP Strobe} $fg_path/sop
add wave -noupdate -group {Frame Generator} -label {EoP Strobe} $fg_path/eop
add wave -noupdate -group {Frame Generator} -label {FG busy} $fg_path/fg_busy
add wave -noupdate -group {Frame Generator} -label {Frame Length} -radix unsigned $fg_path/frame_length
add wave -noupdate -group {Frame Generator} -label {Frame rdy strobe} $fg_path/frame_rdy
add wave -noupdate -group {Frame Generator} -label {Max Payload len} $fg_path/payload_max_len
add wave -noupdate -group {Frame Generator} -label {In FIFO dly} -radix unsigned $fg_path/FIFO_in_dly
add wave -noupdate -group {Frame Generator} -label {Out FIFO dly} -radix unsigned $fg_path/FIFO_out_dly
add wave -noupdate -group {Frame Generator} -label {FG State} $fg_path/state
add wave -noupdate -group {Frame Generator} -label {FG Next state} $fg_path/next_state
add wave -noupdate -group {Frame Generator} -label {Frame word} -radix hexadecimal $fg_path/frame_word
add wave -noupdate -group {Frame Generator} -label {Payload word} -radix hexadecimal $fg_path/payload_word
add wave -noupdate -group {Frame Generator} -label {Payload len sig} $fg_path/payload_length
add wave -noupdate -group {Frame Generator} -label {Generate CRC} $fg_path/gen_crc
# add wave -noupdate -group {Frame Generator} -group {CRC Generator} -label clock $fg_path/CRC32GenD32_1/Clk
# add wave -noupdate -group {Frame Generator} -group {CRC Generator} -label {Clear CRC} $fg_path/CRC32GenD32_1/Clr_CRC
# add wave -noupdate -group {Frame Generator} -group {CRC Generator} -label {Data in} $fg_path/CRC32GenD32_1/Din
# add wave -noupdate -group {Frame Generator} -group {CRC Generator} -label {CRC Out} $fg_path/CRC32GenD32_1/CRC
# add wave -noupdate -group {Frame Generator} -group {CRC Generator} -label {Enable CRC} $fg_path/CRC32GenD32_1/Calc
