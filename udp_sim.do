setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vcom -work work "fifo.vhd"
vcom -work work "fifo_ctrl.vhd"
vcom -work work "udp_parser_top.vhd"
vcom -work work "udp_parser.vhd"
vcom -work work "udp_parser_top_tb.vhd"

vsim +notimingchecks -L work work.udp_parser_top_tb -wlf udp_parser_top_tb.wlf

add wave -noupdate -group udp_parser_top_tb
add wave -noupdate -group udp_parser_top_tb -radix hexadecimal /udp_parser_top_tb/*
add wave -noupdate -group udp_parser_top_tb/udp_parser_top_inst
add wave -noupdate -group udp_parser_top_tb/udp_parser_top_inst -radix hexadecimal /udp_parser_top_tb/udp_parser_top_inst/*
add wave -noupdate -group udp_parser_top_tb/udp_parser_top_inst/udp_parser_inst
add wave -noupdate -group udp_parser_top_tb/udp_parser_top_inst/udp_parser_inst -radix hexadecimal /udp_parser_top_tb/udp_parser_top_inst/udp_parser_inst/*
add wave -noupdate -group udp_parser_top_tb/udp_parser_top_inst/in_fifo
add wave -noupdate -group udp_parser_top_tb/udp_parser_top_inst/in_fifo -radix hexadecimal /udp_parser_top_tb/udp_parser_top_inst/in_fifo/*
add wave -noupdate -group udp_parser_top_tb/udp_parser_top_inst/out_fifo
add wave -noupdate -group udp_parser_top_tbb/udp_parser_top_inst/out_fifo -radix hexadecimal /udp_parser_top_tb/udp_parser_top_inst/out_fifo/*

run -all

