# genus -files genus_shell.tcl

if ![info exists env(GENUSHOME)] {puts "PLEASE SET \"GENUSHOME\" VARIABLE!"; exit 1}
set_db hdl_auto_async_set_reset true
set_db exact_match_seq_async_ctrls true
# set_db library $env(GENUSHOME)/share/synth/tutorials/tech/tutorial.lbr
read_libs $env(GENUSHOME)/share/synth/tutorials/tech/tutorial.lib

set design_file "../source/design/${design_name}.v"

read_hdl $design_file -v2001

elaborate
vcd $design_name
check_design $design_name

# suspend
define_clock -period 67000 -name L15MHz [get_db design:$design_name .ports e]

external_delay -clock L15MHz -input  40000 [get_db design:$design_name .ports -if {.direction==in}]
external_delay -clock L15MHz -output 27000 [get_db design:$design_name .ports -if {.direction==out}]

path_delay -delay 30000 -from [get_db design:$design_name .ports -if {.direction==in}] -to [get_db design:$design_name .ports -if {.direction==out}]
syn_generic
syn_map
syn_opt

write_hdl $design_name > $design_name/results/$design_name.vg; 

report_timing          > $design_name/reports/timing.rpt; 
report_area            > $design_name/reports/area.rpt; 
report_power           > $design_name/reports/power.rpt

#exit
