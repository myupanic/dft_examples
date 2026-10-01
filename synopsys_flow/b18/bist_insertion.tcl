foreach name {B18_RTL B18_TARGET_LIBRARY B18_DW_LIBRARY} {
    if {![info exists env($name)] || $env($name) eq ""} {
        error "Set $name by sourcing setup.sh before running this script"
    }
    if {![file isfile $env($name)]} {
        error "$name does not name a file: $env($name)"
    }
}

analyze -autoread $env(B18_RTL)
set_app_var target_library [list $env(B18_TARGET_LIBRARY)]
set_app_var link_library [list * $env(B18_TARGET_LIBRARY) $env(B18_DW_LIBRARY)]

elaborate b18
current_design b18

compile -exact_map
check_design

change_names -rules verilog -hierarchy
#scan insertion
#set_scan_configuration -style multiplexed_flip_flop

#set_scan_configuration -chain_count 8
set_dft_signal -view existing_dft -type ScanClock -port "clock" -timing [list 45 55]
set_dft_signal -view existing_dft -type Reset -port "reset" -active_state 1
#create_port TEST_SI -direction in
#create_port TEST_SE -direction in
#create_port TEST_SO -direction out
#set_dft_signal -view spec -type ScanDataIn -port TEST_SI
#set_dft_signal -view spec -type ScanDataOut -port TEST_SO
#set_dft_signal -view spec -type ScanEnable -port TEST_SE

# define DFT signals
create_port SI1 -direction in
create_port TM -direction in
create_port LBIST_EN -direction in

set_dft_signal -view spec -type ScanDataIn -port {SI1}
set_dft_signal -view spec -type TestMode -port {TM}
set_dft_signal -view spec -type lbistEnable -port {LBIST_EN}

define_test_mode SCAN -usage wrp_if
define_test_mode LBIST -usage logicbist

set_dft_configuration -logicbist enable -wrapper enable
set_dft_configuration -scan_compression enable -fix_xpropagation enable

set_logicbist_configuration -base_mode SCAN -test_mode LBIST -clock clock -chain_count 40 -prpg_width 16 -misr_width 32 -pattern_counter_width 14

set_dft_configuration -testability enable
#set_testability_configuration -target core_wrapper -control_signal LBIST_EN
set_testability_configuration -target random_resistant -control_signal TM
# ensure that TM is asserted during self-test too
set_test_point_element -control_signal LBIST_EN -type force_1 TM
# define and configure test modes

set_scan_configuration -test_mode SCAN -chain_count 2 -style multiplexed_flip_flop

compile -scan
create_test_protocol
dft_drc
preview_dft
insert_dft

change_names -rules verilog -hierarchy
write -format verilog -output b18_no_seed_signature.vg -hierarchy
write_test_protocol -test_mode LBIST -output b18_LBIST.spf
write_test_protocol -test_mode SCAN -output b18_SCAN.spf
write_test -format stil -output b18_bist_tb
