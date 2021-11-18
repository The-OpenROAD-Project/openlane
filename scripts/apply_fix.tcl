if {[catch {read_lef $::env(MERGED_LEF_UNPADDED)} errmsg]} {
    puts stderr $errmsg
    exit 1
}

foreach lib $::env(LIB_CTS) {
    read_liberty $lib
}
puts "ECO: Successfully read liberty!"

set cur_iter [expr $::env(ECO_ITER) == 0 ? \
                   0 : \
                   [expr {$::env(ECO_ITER) -1}] \
             ]

if {[expr {$cur_iter == 0}]} {
    if {[catch {read_def $::env(CURRENT_DEF)} errmsg]} {
        puts stderr $errmsg
        exit 1
    }
    puts "Reading: $::env(CURRENT_NETLIST)"
    read_verilog $::env(CURRENT_NETLIST)
} else {
    if {[catch {read_def \
            $::env(RUN_DIR)/results/eco/def/eco_$cur_iter.def} errmsg]} {
        puts stderr $errmsg
        exit 1
    }
    puts "Reading: $::env(yosys_result_file_tag)_preroute_eco_$cur_iter.v"
    read_verilog $::env(yosys_result_file_tag)_preroute_eco_$cur_iter.v
}
puts "ECO: Successfully read Verilog!"

read_sdc -echo $::env(CURRENT_SDC)
puts "ECO: Successfully read SDC!"

puts "ECO: Sourcing eco.tcl!"
source $::env(SCRIPTS_DIR)/tcl_commands/eco.tcl

write_verilog $::env(RUN_DIR)/results/eco/net/eco_$::env(ECO_ITER).v
write_def     $::env(RUN_DIR)/results/eco/def/eco_$::env(ECO_ITER).def
set ::env(CURRENT_DEF) $::env(RUN_DIR)/results/eco/def/eco_$::env(ECO_ITER).def

