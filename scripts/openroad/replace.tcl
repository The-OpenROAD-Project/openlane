# Copyright 2020 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if {[catch {read_lef $::env(MERGED_LEF_UNPADDED)} errmsg]} {
    puts stderr $errmsg
    exit 1
}

if {[catch {read_def $::env(CURRENT_DEF)} errmsg]} {
    puts stderr $errmsg
    exit 1
}

if { [info exists ::env(EXTRA_LIBS) ] } {
	foreach lib $::env(EXTRA_LIBS) {
		read_liberty $lib
	}
}

set ::block [[[::ord::get_db] getChip] getBlock]
set ::insts [$::block getInsts]

set free_insts_flag 0

foreach inst $::insts {
	set placement_status [$inst getPlacementStatus]
	if { $placement_status != "FIRM" } {
		set free_insts_flag 1
		break
	}
}

if { ! $free_insts_flag } {
	puts "\[WARN] All instances are FIXED"
	puts "\[WARN] No need to use replace"
	puts "\[WARN] Skipping..."
	file copy -force $::env(CURRENT_DEF) $::env(SAVE_DEF)
	exit 0
}

read_lib $::env(LIB_SYNTH)

set arg_list [list]

lappend arg_list -verbose_level 1
lappend arg_list -density $::env(PL_TARGET_DENSITY)

if { $::env(PL_BASIC_PLACEMENT) } {
	lappend arg_list -overflow 0.9
	lappend arg_list -init_density_penalty 0.0001
	lappend arg_list -initial_place_max_iter 20
	lappend arg_list -bin_grid_count 64
}

if { $::env(PL_TIME_DRIVEN) } {
	read_sdc $::env(CURRENT_SDC)
	read_verilog $::env(yosys_result_file_tag).v
	lappend arg_list -timing_driven
}

if { $::env(PL_ROUTABILITY_DRIVEN) } {
	lappend arg_list -routability_driven
	lappend arg_list -routability_max_density [expr $::env(PL_TARGET_DENSITY) + 0.1]
	lappend arg_list -routability_max_inflation_iter 10
}

if { $::env(PL_SKIP_INITIAL_PLACEMENT) && !$::env(PL_BASIC_PLACEMENT) } {
	lappend arg_list -skip_initial_place
}

puts stderr $arg_list
global_placement {*}$arg_list

write_def $::env(SAVE_DEF)

if {[info exists ::env(CLOCK_PORT)]} {
	if { $::env(PL_ESTIMATE_PARASITICS) == 1 } {
		read_liberty $::env(LIB_SYNTH_COMPLETE)
		read_sdc -echo $::env(CURRENT_SDC)
		# set rc values
		source $::env(SCRIPTS_DIR)/openroad/set_rc.tcl 
		estimate_parasitics -placement

        set ::env(RUN_STANDALONE) 0
        source $::env(SCRIPTS_DIR)/openroad/sta.tcl 
	}
} else {
    puts "\[WARN\]: No CLOCK_PORT found. Skipping STA..."
}
