echo "RUN STARTED AT [date]"

source tcl_scripts/synth_init_lib.tcl
#start from the path of Makefile rather than#

# set saving path of formality file
set DESIGN_NAME pcr2
set_svf ./$env(TIMESTAMP)_run/output/${DESIGN_NAME}.synth.svf

# setup will be included in .synopsys_dc.setup file
source ./.synopsys_dc.setup


###################################################################

#------------------------Specify the libraries---------------------#
set_app_var search_path "$search_path ."
#license is needed#
set_app_var target_library [concat "$DB(ssg0p45v,m40c)"]
#.db, TODO: simplify the way of importing target libs#
#----designware setting-------#
set_app_var synthetic_library "dw_foundation.sldb"
set_dp_smartgen_options -hierarchy -smart_compare true -tp_oper_sel auto -tp_opt_tree auto  -brent_kung_adder true -adder_radix auto -inv_out_adder_cell auto -mult_radix4 auto -sop2pos_transformation auto  -mult_arch auto -optimize_for area,speed
#Analyzes DesignWare datapath extraction.#

set_app_var link_library "* $target_library $synthetic_library"
#all libs which might be used#

#------------------------- Read the design ------------------------#
#----------------------#
## read
### in dc_shell: read -format sverilog rtl.sv
### in tcl shell: read_verilog rtl.v; read_db lib.db

#---------------------#
## or analyze+elaborate+WORK dir(default)

define_design_lib WORK -path ./$env(TIMESTAMP)_run/WORK
#can be omitted#
source tcl_scripts/file_to_list.tcl

analyze -format  sverilog [concat [expand_file_list "$env(PROJ_ROOT)/tb/flist"]]
#analyze HDL source code and save intermediate results named .syn in ./$env(TIMESTAMP)_run/work dir, which can be used by elaborate directly even without anlyzing; TODO: what does es1y_define.sv mean?#
elaborate frontend
# write_file -hierarchy -format verilog -output output/orv64.synth.elaborate.v
#for dbg#
current_design frontend
link
#not necessary after anal. and elab.?, link lib has been defined before#

analyze_datapath_extraction -no_autoungroup


#-------------------- Define the design environment -------------------#
# set_load 2.2 sout
# set_load 1.5 cout
# set_driving_cell -lib_cell FD1 [all_inputs]

#---------------------- Set the design constraints --------------------#

## Design Rule constraints
# set_max_transistion
# set_max_fanout
# set_max_capacitance
#provided by foundary company, can be setted tightly in advance; TODO: get precise indicators#

## Set the optimization constraints

#----delay----#

#----area-----#

source tcl_scripts/constraints.sdc
#copied from original /script/vp_fp.03-05-2020_20.30.59.sdc, TODO: define accurate constraints and optimizations#

# write_sdc output/orv64.synth.elaborate.sdc
# report_clock_tree -structure > rpt/clock_tree_structure.rpt
#for dbg#

#--------------------- Select compile strategy -------------------------#

#--------------------- Synthesize and optimize the design ------------------------#
# echo [get_object_name [get_lib_cells */* -filter dont_use==true]] > rpt/dont_use_list.rpt
# check_design > rpt/check_design.precompile.rpt
#for dbg#
set_verification_top

set_dynamic_optimization true

compile_ultra -gate_clock -retime -no_autoungroup -no_boundary_optimization
#compile_ultra (of DC Ultra) provides concurrent optimization of timing, area, power, and test for high performance designs#
#it also provides advanced delay and arithmetic optimization, advanced timing analysis, automatic leakage power optimization, and register retiming#

#--------------------- Analyze and debug the design/resolve design problems --------------------#

analyze_datapath > ./$env(TIMESTAMP)_run/rpt/datapath.compile.rpt
report_resources > ./$env(TIMESTAMP)_run/rpt/resources.compile.rpt
write_file -hierarchy -format verilog -output ./$env(TIMESTAMP)_run/output/orv64.synth.compile.v
write_sdc ./$env(TIMESTAMP)_run/output/orv64.synth.compile.sdc

update_timing
report_timing -nosplit > ./$env(TIMESTAMP)_run/rpt/timing.compile.rpt
report_area -nosplit -hier > ./$env(TIMESTAMP)_run/rpt/area.hier.compile.rpt

check_design > ./$env(TIMESTAMP)_run/rpt/check_design.preopt.rpt
optimize_netlist -area -no_boundary_optimization
check_design > ./$env(TIMESTAMP)_run/rpt/check_design.postopt.rpt

define_name_rules preserve_struct_bus_rule -preserve_struct_ports
define_name_rules ours_verilog_name_rule -allowed "a-z A-Z 0-9 _" \
  -check_internal_net_name \
  -case_insensitive

change_names -rules preserve_struct_bus_rule -hierarchy -log_changes ./$env(TIMESTAMP)_run/rpt/struct_name_change.log
change_names -rules ours_verilog_name_rule   -hierarchy -log_changes ./$env(TIMESTAMP)_run/rpt/legalize_name_change.log
write -format verilog -hierarchy -output ./$env(TIMESTAMP)_run/output/orv64.synth.final.v
write -format ddc -hierarchy -output ./$env(TIMESTAMP)_run/output/orv64.synth.final.ddc
write_sdc -nosplit ./$env(TIMESTAMP)_run/output/orv64.synth.final.sdc

report_clock_gating > ./$env(TIMESTAMP)_run/rpt/clock_gating.rpt
report_timing -max_paths 500 -significant_digits 3 -nosplit > ./$env(TIMESTAMP)_run/rpt/synth.timing.rpt
report_timing -delay_type min -max_paths 500 -input_pins -nets -transition_time -capacitance -significant_digits 3 > ./$env(TIMESTAMP)_run/rpt/synth.min_delay.rpt
report_timing -delay_type max -max_paths 500 -input_pins -nets -transition_time -capacitance -significant_digits 3 > ./$env(TIMESTAMP)_run/rpt/synth.max_delay.rpt
report_constraint -all_violators -significant_digits 3 > ./$env(TIMESTAMP)_run/rpt/synth.all_viol_constraints.rpt
report_area -nosplit -hier > ./$env(TIMESTAMP)_run/rpt/synth.area.hier.rpt
report_resources -nosplit -hier > ./$env(TIMESTAMP)_run/rpt/synth.resources.rpt

report_compile_options -nosplit > ./$env(TIMESTAMP)_run/rpt/synth.compile_options.rpt

#--------------------- Save the design database ---------------------#
write_file -format ddc -hierarchy -output ./$env(TIMESTAMP)_run/output/${DESIGN_NAME}.ddc
#.ddc is the whole project, can be modified and checked#
write_file -format verilog -hierarchy -output ./$env(TIMESTAMP)_run/output/${DESIGN_NAME}_netlist.v
#netlist.v for P&R and sim#
write_sdf ./$env(TIMESTAMP)_run/output/${DESIGN_NAME}_sdf
#recording the latency of std cells, also useful for post-sim#
write_parasitics -output ./$env(TIMESTAMP)_run/output/${DESIGN_NAME}_parasitics
#Writes parasitics in SPEF format or as a Tcl script that contains set_load and set_resistance commands.#
# write_sdc sdc_file_name
#Writes out a script in Synopsys Design Constraints (SDC) format.#
#This script contains commands that can be used with PrimeTime or with Design Compiler. SDC is also licensed by external vendors through the Tap-in program. SDC-formatted script files are read into PrimeTime or Design Compiler using the read_sdc command.#
# write_floorplan -all ./$env(TIMESTAMP)_run/output/${DESIGN_NAME}_phys_cstr_file_name.tcl
#writes a Tcl script file that contains floorplan information for the current or user-specified design. writes commands relative to the top of the design, regardless of the current instance.#


#-------------------------------------------------------------------#
echo "RUN ENDED AT [date]"
