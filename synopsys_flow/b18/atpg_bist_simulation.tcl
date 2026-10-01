if {![info exists env(B18_TMAX_LIBRARY)] || $env(B18_TMAX_LIBRARY) eq ""} {
    error "Set B18_TMAX_LIBRARY by sourcing setup.sh before running this script"
}
if {![file isfile $env(B18_TMAX_LIBRARY)]} {
    error "B18_TMAX_LIBRARY does not name a file: $env(B18_TMAX_LIBRARY)"
}
foreach input {b18_no_seed_signature.vg b18_LBIST.spf} {
    if {![file isfile $input]} {
        error "Missing $input in [pwd]; run bist_insertion.tcl here first"
    }
}

read_netlist -library $env(B18_TMAX_LIBRARY)
read_netlist b18_no_seed_signature.vg
run_build_model

set_drc -seq_comp_jtag_lbist_mode light_lbist
set_drc -allow_unstable_set_reset

run_drc b18_LBIST.spf
run_atpg -auto -jtag_lbist {1 16383 1} > b18_max.rpt

run_simulation
report_patterns -all

# write serial STIL file containing seed and signature values
write_patterns b18_after_simulation.stil -format stil -replace -unified -serial
