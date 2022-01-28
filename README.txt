This repo can be used to synthesize your RTL design using Design Compiler from Synopsys.

The recommended path is %(PROJ_ROOT)/syn/dc_syn_scripts. If not, please change the environment variable %(PROJ_ROOT) in Makefile to ensure scripts can get your design files.

Before you start your synthesis, make sure you have prepared the following supporting files and make necessary changes in dc_syn_scripts/tcl_scripts/synth.tcl to specify your design name and top design.

1. Prepare file_list of your design.
2. Add your file_list to dc_syn_scripts/tcl_scripts/synth.tcl, eg. analyze -format  sverilog [concat [expand_file_list "$env(PROJ_ROOT)/rtl/file_list"]]
3. Assign top file, eg. elaborate frontend
4. Assign current design, eg, current_design frontend
5. Change DESIGN_NAME in dc_syn_scripts/tcl_scripts/synth.tcl, the default is pcr2.
