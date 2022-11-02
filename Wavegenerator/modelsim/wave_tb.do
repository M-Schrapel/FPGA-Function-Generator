onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix unsigned /pwm_calculator_testbench/clock
add wave -noupdate -radix unsigned /pwm_calculator_testbench/reset
add wave -noupdate -radix unsigned /pwm_calculator_testbench/data_request
add wave -noupdate -radix unsigned /pwm_calculator_testbench/period_in
add wave -noupdate -radix unsigned /pwm_calculator_testbench/period_on_in
add wave -noupdate -radix unsigned /pwm_calculator_testbench/amp
add wave -noupdate -radix unsigned /pwm_calculator_testbench/data_avail
add wave -noupdate -radix unsigned /pwm_calculator_testbench/period_on
add wave -noupdate -radix unsigned /pwm_calculator_testbench/n_periods
add wave -noupdate -radix unsigned /pwm_calculator_testbench/last_period
add wave -noupdate -radix unsigned /pwm_calculator_testbench/last_period_on
add wave -noupdate /pwm_calculator_testbench/pwm_calc/mapping_calc/data_avail
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {74525 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 153
configure wave -valuecolwidth 40
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {100307 ps}
