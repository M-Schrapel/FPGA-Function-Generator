onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -label clock -radix unsigned /wave_updatelogic_testbench/clock
add wave -noupdate -label reset -radix unsigned /wave_updatelogic_testbench/reset
add wave -noupdate -radix unsigned /wave_updatelogic_testbench/enable_request_wave(0)
add wave -noupdate -radix unsigned /wave_updatelogic_testbench/data_request_wave(0)
add wave -noupdate -label enable_request_wave -radix unsigned -childformat {{/wave_updatelogic_testbench/enable_request_wave(1) -radix unsigned} {/wave_updatelogic_testbench/enable_request_wave(0) -radix unsigned}} -subitemconfig {/wave_updatelogic_testbench/enable_request_wave(1) {-height 15 -radix unsigned} /wave_updatelogic_testbench/enable_request_wave(0) {-height 15 -radix unsigned}} /wave_updatelogic_testbench/enable_request_wave
add wave -noupdate -label data_request_wave -radix unsigned -childformat {{/wave_updatelogic_testbench/data_request_wave(1) -radix unsigned} {/wave_updatelogic_testbench/data_request_wave(0) -radix unsigned}} -expand -subitemconfig {/wave_updatelogic_testbench/data_request_wave(1) {-height 15 -radix unsigned} /wave_updatelogic_testbench/data_request_wave(0) {-height 15 -radix unsigned}} /wave_updatelogic_testbench/data_request_wave
add wave -noupdate -label mult_request_wave -radix unsigned /wave_updatelogic_testbench/mult_request_wave
add wave -noupdate -label pwm_step_request_wave -radix unsigned /wave_updatelogic_testbench/pwm_step_request_wave
add wave -noupdate -label freq_request_wave -radix unsigned /wave_updatelogic_testbench/freq_request_wave
add wave -noupdate -label function_request_wave -radix unsigned /wave_updatelogic_testbench/function_request_wave
add wave -noupdate -radix unsigned /wave_updatelogic_testbench/data_avail_response_wave(0)
add wave -noupdate -label data_avail_response_wave -radix unsigned -childformat {{/wave_updatelogic_testbench/data_avail_response_wave(1) -radix unsigned} {/wave_updatelogic_testbench/data_avail_response_wave(0) -radix unsigned}} -subitemconfig {/wave_updatelogic_testbench/data_avail_response_wave(1) {-height 15 -radix unsigned} /wave_updatelogic_testbench/data_avail_response_wave(0) {-height 15 -radix unsigned}} /wave_updatelogic_testbench/data_avail_response_wave
add wave -noupdate -label mult_response_wave -radix unsigned /wave_updatelogic_testbench/mult_response_wave
add wave -noupdate -label period_on_response_wave -radix unsigned /wave_updatelogic_testbench/period_on_response_wave
add wave -noupdate -label n_periods_response_wave -radix unsigned /wave_updatelogic_testbench/n_periods_response_wave
add wave -noupdate -label last_period_response_wave -radix unsigned /wave_updatelogic_testbench/last_period_response_wave
add wave -noupdate -label last_period_on_response_wave -radix unsigned /wave_updatelogic_testbench/last_period_on_response_wave
add wave -noupdate -label freq_response_wave -radix unsigned /wave_updatelogic_testbench/freq_response_wave
add wave -noupdate -label function_response_wave -radix unsigned /wave_updatelogic_testbench/function_response_wave
add wave -noupdate -label pwm_step_response_wave -radix unsigned /wave_updatelogic_testbench/pwm_step_response_wave
add wave -noupdate -label data_request_rom -radix unsigned /wave_updatelogic_testbench/data_request_rom
add wave -noupdate -label function_request_rom -radix unsigned /wave_updatelogic_testbench/function_request_rom
add wave -noupdate -label frequency_request_rom -radix unsigned /wave_updatelogic_testbench/frequency_request_rom
add wave -noupdate -label step_request_rom -radix unsigned /wave_updatelogic_testbench/step_request_rom
add wave -noupdate -label mult_request_rom -radix unsigned /wave_updatelogic_testbench/mult_request_rom
add wave -noupdate -label data_avail_response_rom -radix unsigned /wave_updatelogic_testbench/data_avail_response_rom
add wave -noupdate -label period_on_response_rom -radix unsigned /wave_updatelogic_testbench/period_on_response_rom
add wave -noupdate -label n_periods_response_rom -radix unsigned /wave_updatelogic_testbench/n_periods_response_rom
add wave -noupdate -label last_period_response_rom -radix unsigned /wave_updatelogic_testbench/last_period_response_rom
add wave -noupdate -label last_period_on_response_rom -radix unsigned /wave_updatelogic_testbench/last_period_on_response_rom
add wave -noupdate -label write_custom_request_rom -radix unsigned /wave_updatelogic_testbench/write_custom_request_rom
add wave -noupdate -label address_request_rom -radix unsigned /wave_updatelogic_testbench/address_request_rom
add wave -noupdate -label pwm_value_request_rom -radix unsigned /wave_updatelogic_testbench/pwm_value_request_rom
add wave -noupdate -label ext_request -radix unsigned /wave_updatelogic_testbench/ext_request
add wave -noupdate -label type_request -radix unsigned /wave_updatelogic_testbench/type_request
add wave -noupdate -label wave_unit_select -radix unsigned /wave_updatelogic_testbench/wave_unit_select
add wave -noupdate -label function_select -radix unsigned /wave_updatelogic_testbench/function_select
add wave -noupdate -label frequency_select -radix unsigned /wave_updatelogic_testbench/frequency_select
add wave -noupdate -label mult_select -radix unsigned /wave_updatelogic_testbench/mult_select
add wave -noupdate -label phasereference_select -radix unsigned /wave_updatelogic_testbench/phasereference_select
add wave -noupdate -label phase_value_select -radix unsigned /wave_updatelogic_testbench/phase_value_select
add wave -noupdate -label data_back -radix unsigned /wave_updatelogic_testbench/data_back
add wave -noupdate -label write_custom_request -radix unsigned /wave_updatelogic_testbench/write_custom_request
add wave -noupdate -label address_request -radix unsigned /wave_updatelogic_testbench/address_request
add wave -noupdate -label pwm_value_request -radix unsigned /wave_updatelogic_testbench/pwm_value_request
add wave -noupdate -label ack_ext -radix unsigned /wave_updatelogic_testbench/ack_ext
add wave -noupdate -radix unsigned /wave_updatelogic_testbench/req_wcnt
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {110537 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 208
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
WaveRestoreZoom {0 ps} {326615 ps}
