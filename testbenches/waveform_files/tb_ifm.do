onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group {In FIFO Manager} -label {Clock} $ifm_path/clock
add wave -noupdate -group {In FIFO Manager} -label {Reset}  $ifm_path/reset
add wave -noupdate -group {In FIFO Manager} -label {Data out} -radix hex $ifm_path/data_out
add wave -noupdate -group {In FIFO Manager} -label {Usedw out} -radix unsigned $ifm_path/usedw_out
add wave -noupdate -group {In FIFO Manager} -label {Payload rdy} $ifm_path/payload_rdy
add wave -noupdate -group {In FIFO Manager} -label {TX Busy}  $ifm_path/tx_busy
add wave -noupdate -group {In FIFO Manager} -label {rdreq in} $ifm_path/rdreq
add wave -noupdate -group {In FIFO Manager} -label {Payload Min Sizes} -radix unsigned $ifm_path/payload_size
add wave -noupdate -group {In FIFO Manager} -label {wrclks} $ifm_path/wrclks
add wave -noupdate -group {In FIFO Manager} -label {wrreqs} $ifm_path/wrreqs
add wave -noupdate -group {In FIFO Manager} -label {flags} $ifm_path/flags
add wave -noupdate -group {In FIFO Manager} -label {Data ins} -radix hex $ifm_path/data_in
add wave -noupdate -group {In FIFO Manager} -label {FIFOs full} $ifm_path/wrfull
add wave -noupdate -group {In FIFO Manager} -label {Read Usedw} -radix unsigned $ifm_path/rdusedw
add wave -noupdate -group {In FIFO Manager} -label {FIFOs data} -radix hex $ifm_path/fifo_outs
add wave -noupdate -group {In FIFO Manager} -label {Read Requests} $ifm_path/rdreqs
add wave -noupdate -group {In FIFO Manager} -label {FIFOs empty} $ifm_path/rdempty
add wave -noupdate -group {In FIFO Manager} -label {Mux select} -radix unsigned $ifm_path/mux_sel
add wave -noupdate -group {In FIFO Manager} -label {FIFO flush} $ifm_path/fifo_flush

#Setup our FIFOs
for {set i 0} {$i < [examine NFIFOS]} {incr i} {
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Reset} $ifm_path/fifo_gen($i)/fifo_32x2048_0/aclr
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Data In} -radix hex $ifm_path/fifo_gen($i)/fifo_32x2048_0/data
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Rdclk} $ifm_path/fifo_gen($i)/fifo_32x2048_0/rdclk
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Rdreq} $ifm_path/fifo_gen($i)/fifo_32x2048_0/rdreq
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Wrclk} $ifm_path/fifo_gen($i)/fifo_32x2048_0/wrclk
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Wrreq} $ifm_path/fifo_gen($i)/fifo_32x2048_0/wrreq
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Data Out} -radix hex $ifm_path/fifo_gen($i)/fifo_32x2048_0/q
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Rdempty} $ifm_path/fifo_gen($i)/fifo_32x2048_0/rdempty
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Rdusedw} -radix unsigned $ifm_path/fifo_gen($i)/fifo_32x2048_0/rdusedw
add wave -noupdate -group {In FIFO Manager} -group FIFO_$i -label {Wrfull} $ifm_path/fifo_gen($i)/fifo_32x2048_0/wrfull
}

update