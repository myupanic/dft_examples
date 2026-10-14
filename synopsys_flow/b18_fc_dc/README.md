# B18 scan in Fusion Compiler, post-scan LBIST in Design Compiler

This example synthesizes the ITC'99 B18 VHDL design and inserts plain scan in Fusion Compiler (FC), then inserts LogicBIST into the scanned netlist in Design Compiler (DC). The RTL, SAED32 PDK, and DesignWare library are supplied by the user. Both tool executables must be available in `PATH` with the licenses required for synthesis and the corresponding DFT stages.

## Configure

Copy `setup.local.sh.example` to `setup.local.sh` in this directory:

```bash
cp /path/to/dft_examples/synopsys_flow/b18_fc_dc/setup.local.sh.example \
   /path/to/dft_examples/synopsys_flow/b18_fc_dc/setup.local.sh
```

Edit the three required settings, using quoted absolute paths:

| Variable | Input |
| --- | --- |
| `B18_RTL` | B18 VHDL source, `b18.vhd` |
| `B18_PDK_ROOT` | SAED32 EDK installation directory |
| `B18_DW_LIBRARY` | DesignWare `dw_foundation.sldb`, shared by FC and DC |

`setup.sh` derives the following file paths from `B18_PDK_ROOT`. Override any of these variables in `setup.local.sh` if your installation uses a different layout. Both tools use the same `B18_TARGET_LIBRARY` and `B18_DW_LIBRARY`.

| Variable | Default path relative to `B18_PDK_ROOT` |
| --- | --- |
| `B18_TARGET_LIBRARY` | `lib/stdcell_rvt/db_nldm/saed32rvt_tt1p05v125c.db` |
| `B18_LEF_FILE` | `lib/stdcell_rvt/lef/saed32nm_rvt_1p9m.lef` |
| `B18_TECH_FILE` | `tech/milkyway/saed32nm_1p9m_mw.v10.tf` |
| `B18_RC_MAX_FILE` | `tech/star_rcxt/saed32nm_1p9m_Cmax.tluplus` |
| `B18_RC_MIN_FILE` | `tech/star_rcxt/saed32nm_1p9m_Cmin.tluplus` |
| `B18_RC_MAP_FILE` | `tech/star_rcxt/saed32nm_tf_itf_tluplus.map` |

The logical, physical, and RC files must describe a consistent technology. The defaults preserve the original flow's SAED32 RVT corner and nine-metal setup. TetraMAX configuration is not required for these two insertion stages.

Optional settings:

- `B18_SCAN_CHAIN_COUNT`: defaults to `32`. Enter a positive integer without leading zeros. Both stages read this same value; DC also uses it for the LBIST chain count.
- `B18_WORK_DIR`: defaults to this example's `work/` directory. Override it with an absolute path to use a different run directory. Use a fresh work directory when changing the chain count, libraries, or RTL so that generated files belong to the same run.

You can export these variables in Bash instead of creating `setup.local.sh`. If the local file exists, it is sourced after the shell's existing settings and its assignments take precedence. The setup validates the input paths and chain count, creates the work directory, and exports the settings to both tools. To change the PDK root or switch between B18 examples, clear previously exported `B18_*` settings or start a fresh terminal session before sourcing the setup, so that old file overrides and work-directory settings are not reused.

## Run

From a Bash shell, in any directory:

```bash
source /path/to/dft_examples/synopsys_flow/b18_fc_dc/setup.sh
cd "$B18_WORK_DIR"
fc_shell -f "$B18_EXAMPLE_DIR/scan_insertion_fc.tcl"
```

After FC completes successfully, run DC in the same configured environment and work directory:

```bash
dc_shell -f "$B18_EXAMPLE_DIR/bist_insertion_dc_after_fc.tcl"
```

Both Tcl scripts select `B18_WORK_DIR` before processing the design. Starting the tool commands from that directory also keeps their startup logs there. The FC-to-DC handoff is `b18_scan.vg`. DC reads this netlist, recognizes its existing scan chains, and adds LBIST; it does not read the FC SPF. The FC SPF is an accompanying scan-protocol artifact.

The scripts retain the working flow's functional clock period of `10.0`, active-high reset, scan-clock timing of `{45 55}`, starting floorplan of `{400 400}` with `{5 5 5 5}` core offsets, and LBIST pattern-counter width of `14`. DC chooses PRPG and MISR widths using its chain-count heuristics. Inspect DFT DRC, preview, and scan-path reports for both stages.

## Outputs

All generated outputs go into `B18_WORK_DIR`:

| Stage | Output | Purpose |
| --- | --- | --- |
| FC | `b18_scan.vg` | Scanned netlist consumed by DC |
| FC | `b18_SCAN.spf` | Scan protocol before LBIST insertion |
| FC | `b18_saed32_scan32.dlib` | FC design library; the number follows `B18_SCAN_CHAIN_COUNT`, with the scanned block saved as `b18_scan.design` |
| DC | `b18_no_seed_signature.vg` | Netlist after LBIST insertion |
| DC | `b18_SCAN_after_lbist.spf` | Scan protocol after LBIST insertion |
| DC | `b18_LBIST.spf` | LBIST protocol |
| DC | `b18_bist_tb*` | Generated STIL test and testbench files |

The export commands remain inside each script's successful `insert_dft` branch. DC checks that the expected `SI1`/`SO1` through `SI<N>`/`SO<N>` ports exist in the handoff. Use `b18_SCAN_after_lbist.spf` when checking scan on the final LBIST netlist; `b18_SCAN.spf` describes the FC stage.

## Share

Share the two Tcl scripts, `setup.sh`, `setup.local.sh.example`, and this README. Recipients supply their own RTL, PDK, and DesignWare paths. `setup.local.sh` and the default `work/` directory are ignored by Git. When sharing a zip or using an external work directory, exclude local configuration and generated outputs yourself.
