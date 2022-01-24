# User config
set ::env(DESIGN_NAME) def_test

# Change if needed
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/src/*.v]

# turn off clock
set ::env(CLOCK_TREE_SYNTH) 0
set ::env(CLOCK_PORT) ""

set ::env(PL_RANDOM_GLB_PLACEMENT) 1

#set ::env(FP_PDN_VPITCH) 153.6
#set ::env(FP_PDN_HPITCH) 153.18

set ::env(FP_DEF_TEMPLATE) $::env(DESIGN_DIR)/def_test.def

set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 300 300"
set ::env(PL_TARGET_DENSITY) 0.75

set ::env(FP_HORIZONTAL_HALO) 6
set ::env(FP_VERTICAL_HALO) $::env(FP_HORIZONTAL_HALO)

set ::env(DIODE_INSERTION_STRATEGY) 3



set filename $::env(DESIGN_DIR)/$::env(PDK)_$::env(STD_CELL_LIBRARY)_config.tcl
if { [file exists $filename] == 1} {
	source $filename
}
