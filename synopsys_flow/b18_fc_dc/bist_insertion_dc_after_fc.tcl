set dut b18
set_app_var sh_continue_on_error false

# Settings are shared by the FC scan and DC post-scan LBIST stages.
foreach name {B18_TARGET_LIBRARY B18_DW_LIBRARY B18_WORK_DIR B18_SCAN_CHAIN_COUNT} {
    if {![info exists env($name)] || $env($name) eq ""} {
        error "Set $name by sourcing setup.sh before running this script"
    }
}
if {![regexp {^[1-9][0-9]*$} $env(B18_SCAN_CHAIN_COUNT)]} {
    error "B18_SCAN_CHAIN_COUNT must be a positive integer without leading zeros"
}
if {[file pathtype $env(B18_WORK_DIR)] ne "absolute" ||
    ![file isdirectory $env(B18_WORK_DIR)]} {
    error "B18_WORK_DIR must be an existing absolute directory; source setup.sh first"
}
cd $env(B18_WORK_DIR)

set SCAN_CHAIN_COUNT $env(B18_SCAN_CHAIN_COUNT)
set LBIST_CHAIN_COUNT $SCAN_CHAIN_COUNT
set SCAN_NETLIST ${dut}_scan.vg

# Match the logical library and corner used by FC scan insertion.
set DB_FILE $env(B18_TARGET_LIBRARY)
set DW_FILE $env(B18_DW_LIBRARY)

foreach input_file [list $DB_FILE $DW_FILE] {
    if {[file pathtype $input_file] ne "absolute" ||
        ![file isfile $input_file] || ![file readable $input_file]} {
        error "Required input must be an absolute path to a readable file: $input_file"
    }
}
if {![file isfile $SCAN_NETLIST]} {
    error "Missing $SCAN_NETLIST in [pwd]; run scan_insertion_fc.tcl successfully here first"
}

# Configure libraries before reading and linking the scanned netlist.
set_app_var search_path [concat $search_path [list \
    [file dirname $DB_FILE] \
    [file dirname $DW_FILE]]]
set_app_var target_library    [list $DB_FILE]
set_app_var synthetic_library [list $DW_FILE]
set_app_var link_library \
    [concat [list *] $target_library $synthetic_library]

read_verilog $SCAN_NETLIST
current_design $dut
link
#check_design

# Reject an old handoff that lacks the expected scan ports.
set scan_in_ports {}
set scan_out_ports {}
for {set chain_index 1} {$chain_index <= $SCAN_CHAIN_COUNT} {incr chain_index} {
    set si SI${chain_index}
    set so SO${chain_index}
    foreach scan_port [list $si $so] {
        if {[sizeof_collection [get_ports -quiet $scan_port]] != 1} {
            error "Missing scan port '$scan_port': regenerate $SCAN_NETLIST in FC with $SCAN_CHAIN_COUNT chains."
        }
    }
    lappend scan_in_ports $si
    lappend scan_out_ports $so
}

# Declare the encoding port before defining modes that use it.
create_port TM -direction in
create_port LBIST_EN -direction in
set_dft_signal -view spec -type TestMode -port TM
set_dft_configuration -scan enable -logicbist enable

define_test_mode SCAN -usage scan -encoding {TM 0}
define_test_mode LBIST -usage logicbist -encoding {TM 1}
set_dft_signal -view spec -type lbistEnable -port LBIST_EN -test_mode LBIST

# Recognize the stitched FC chains as existing DFT structures.
set_scan_configuration -style multiplexed_flip_flop -replace false
set_scan_configuration -test_mode SCAN -chain_count $SCAN_CHAIN_COUNT
set_scan_state scan_existing
set_dft_signal -view existing_dft -type ScanClock -port clock \
    -timing {45 55} -test_mode all
set_dft_signal -view existing_dft -type Reset -port reset \
    -active_state 1 -test_mode all
# Describe the imported chain endpoints for scan extraction.
set_dft_signal -view existing_dft -type ScanDataIn -port $scan_in_ports \
    -test_mode SCAN
set_dft_signal -view existing_dft -type ScanDataOut -port $scan_out_ports \
    -test_mode SCAN
set_dft_signal -view existing_dft -type ScanEnable -port SE \
    -test_mode all

# Also specify the existing ports as the base-mode interface for LBIST.
set_dft_signal -view spec -type ScanDataIn -port $scan_in_ports \
    -test_mode SCAN
set_dft_signal -view spec -type ScanDataOut -port $scan_out_ports \
    -test_mode SCAN
set_dft_signal -view spec -type ScanEnable -port SE \
    -test_mode all
for {set chain_index 1} {$chain_index <= $SCAN_CHAIN_COUNT} {incr chain_index} {
    set_scan_path SCAN_CHAIN_${chain_index} -view existing_dft -test_mode SCAN \
        -scan_data_in SI${chain_index} -scan_data_out SO${chain_index}
}

# Let DC choose PRPG/MISR widths using its chain-count-based heuristics.
# Inspect the preview report for the selected register widths and chain count.
set_logicbist_configuration -base_mode SCAN -test_mode LBIST \
    -clock clock -chain_count $LBIST_CHAIN_COUNT \
    -pattern_counter_width 14

create_test_protocol

# Check and report the imported SCAN mode explicitly.
current_test_mode SCAN
dft_drc
report_scan_path -view existing_dft -chain all

# Check the requested LBIST mode before architecture and insertion.
current_test_mode LBIST
dft_drc
preview_dft -show all

# DC can continue sourcing later commands after an error. Keep all exports
# inside the success branch so a failed insertion cannot export a result.
if {[insert_dft]} {
    foreach test_mode_iter {SCAN LBIST} {
        current_test_mode $test_mode_iter
        dft_drc
        report_scan_path -view existing_dft -chain all
    }

    change_names -rules verilog -hierarchy
    write -format verilog -output b18_no_seed_signature.vg -hierarchy
    write_test_protocol -test_mode SCAN -output b18_SCAN_after_lbist.spf
    write_test_protocol -test_mode LBIST -output b18_LBIST.spf
    write_test -format stil -output b18_bist_tb
} else {
    error "LogicBIST insertion failed; netlist/SPF/testbench export skipped."
}
