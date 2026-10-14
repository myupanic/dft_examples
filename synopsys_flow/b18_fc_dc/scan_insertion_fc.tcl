set dut b18
set_app_var sh_continue_on_error false

# Settings are shared by the FC scan and DC post-scan LBIST stages.
foreach name {B18_RTL B18_TARGET_LIBRARY B18_DW_LIBRARY
    B18_LEF_FILE B18_TECH_FILE B18_RC_MAX_FILE B18_RC_MIN_FILE B18_RC_MAP_FILE
    B18_WORK_DIR B18_SCAN_CHAIN_COUNT} {
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

set RTL_FILE $env(B18_RTL)
set DB_FILE $env(B18_TARGET_LIBRARY)
set DW_FILE $env(B18_DW_LIBRARY)
set LEF_FILE $env(B18_LEF_FILE)
set TECH_FILE $env(B18_TECH_FILE)
set RC_MAX_FILE $env(B18_RC_MAX_FILE)
set RC_MIN_FILE $env(B18_RC_MIN_FILE)
set RC_MAP_FILE $env(B18_RC_MAP_FILE)

foreach input_file [list $RTL_FILE $DB_FILE $LEF_FILE $TECH_FILE $DW_FILE \
    $RC_MAX_FILE $RC_MIN_FILE $RC_MAP_FILE] {
    if {[file pathtype $input_file] ne "absolute" ||
        ![file isfile $input_file] || ![file readable $input_file]} {
        error "Required input must be an absolute path to a readable file: $input_file"
    }
}

# Configure logical libraries BEFORE creating the FC design library.
set_app_var search_path [concat $search_path [list \
    [file dirname $DB_FILE] \
    [file dirname $LEF_FILE] \
    [file dirname $DW_FILE]]]

set_app_var target_library    [list $DB_FILE]
set_app_var synthetic_library [list $DW_FILE]
set_app_var link_library \
    [concat [list *] $target_library $synthetic_library]

# Use a separate design library for this chain-count experiment.
set DESIGN_LIBRARY ${dut}_saed32_scan${SCAN_CHAIN_COUNT}.dlib
create_lib -technology $TECH_FILE \
    -ref_libs [list $LEF_FILE] \
    $DESIGN_LIBRARY

# Read and elaborate the benchmark.
analyze -autoread -top $dut $RTL_FILE
elaborate $dut
set_top_module $dut

# Load RC models and assign both analyses of the default corner.
read_parasitic_tech -tlup $RC_MAX_FILE \
    -layermap $RC_MAP_FILE -name RC_MAX
read_parasitic_tech -tlup $RC_MIN_FILE \
    -layermap $RC_MAP_FILE -name RC_MIN
set_parasitic_parameters -corners default \
    -late_spec RC_MAX -early_spec RC_MIN

# Select DFT insertion after logic optimization.
set_app_options -name dft.insertion_post_logic_opto -value true

# Example functional timing target, in library time units.
create_clock -name CLK -period 10.0 [get_ports clock]

# Routing directions from the supplied SAED32 FC setup.
set_attribute [get_layers {M1 M3 M5 M7 M9}] routing_direction horizontal
set_attribute [get_layers {M2 M4 M6 M8}] routing_direction vertical

# Simple starting floorplan for benchmark experiments.
initialize_floorplan -side_length {400 400} \
    -core_offset {5 5 5 5}

# 1. Prepare scan ports and signals. Keep these names fixed: the separate
# LBIST stage reads the exported netlist and identifies these existing chains.
set scan_in_ports {}
set scan_out_ports {}
for {set chain_index 1} {$chain_index <= $SCAN_CHAIN_COUNT} {incr chain_index} {
    set si SI${chain_index}
    set so SO${chain_index}
    create_port $si -direction in
    create_port $so -direction out
    lappend scan_in_ports $si
    lappend scan_out_ports $so
}
create_port SE -direction in

define_test_mode SCAN -usage scan
set_dft_signal -view existing_dft -type ScanClock -port clock \
    -timing {45 55} -test_mode SCAN
set_dft_signal -view existing_dft -type Reset -port reset \
    -active_state 1 -test_mode SCAN
set_dft_signal -view spec -type ScanDataIn -port $scan_in_ports \
    -test_mode SCAN
set_dft_signal -view spec -type ScanDataOut -port $scan_out_ports \
    -test_mode SCAN
set_dft_signal -view spec -type ScanEnable -port SE -test_mode SCAN

# 2. Configure plain, uncompressed scan. No LBIST, compression, OCC, or test
# points are inserted here; LBIST is a separate netlist-based stage.
set_dft_configuration -scan enable
set_scan_configuration -test_mode SCAN -chain_count $SCAN_CHAIN_COUNT \
    -style multiplexed_flip_flop
for {set chain_index 1} {$chain_index <= $SCAN_CHAIN_COUNT} {incr chain_index} {
    set_scan_path SCAN_CHAIN_${chain_index} -view spec -test_mode SCAN \
        -scan_data_in SI${chain_index} -scan_data_out SO${chain_index}
}

# 3-5. Follow the FC DFT.tcl sequence after logic_opto.
# Synthesize and map the RTL.
compile_fusion -to logic_opto
create_test_protocol
dft_drc -test_mode all_dft
preview_dft
# Export the handoff only after scan insertion succeeds.
if {[insert_dft]} {
    dft_drc -coverage_estimate
    current_test_mode SCAN
    report_scan_path -chain all

    # 6. Export the scanned netlist and SPF files for the DC LBIST stage.
    change_names -rules verilog -hierarchy
    foreach test_mode_iter [all_test_modes] {
        write_test_protocol -test_mode $test_mode_iter \
            -output b18_${test_mode_iter}.spf
    }
    write_verilog -hierarchy all b18_scan.vg
    save_block -force b18 -as b18_scan.design
} else {
    error "FC scan insertion failed; scan-netlist/SPF export skipped."
}
