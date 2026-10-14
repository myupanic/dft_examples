#!/usr/bin/env bash
# Source this file from Bash before running the FC scan and DC LBIST scripts.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    printf 'Source this file: source %s\n' "$0" >&2
    exit 1
fi

_b18_fc_dc_setup() {
    local example_dir name value
    example_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || return 1

    if [[ -f "$example_dir/setup.local.sh" ]]; then
        source "$example_dir/setup.local.sh" || return 1
    fi

    if [[ -z ${B18_PDK_ROOT-} ]]; then
        printf 'Missing B18_PDK_ROOT. Set it in %s/setup.local.sh or export it first.\n' "$example_dir" >&2
        return 1
    fi
    if [[ $B18_PDK_ROOT != /* || ! -d $B18_PDK_ROOT ]]; then
        printf 'B18_PDK_ROOT must be an absolute path to an existing directory: %s\n' "$B18_PDK_ROOT" >&2
        return 1
    fi

    # Defaults match the SAED32 RVT library, corner, and physical files used
    # by the original working flow. Each file can be overridden independently.
    B18_TARGET_LIBRARY=${B18_TARGET_LIBRARY:-$B18_PDK_ROOT/lib/stdcell_rvt/db_nldm/saed32rvt_tt1p05v125c.db}
    B18_LEF_FILE=${B18_LEF_FILE:-$B18_PDK_ROOT/lib/stdcell_rvt/lef/saed32nm_rvt_1p9m.lef}
    B18_TECH_FILE=${B18_TECH_FILE:-$B18_PDK_ROOT/tech/milkyway/saed32nm_1p9m_mw.v10.tf}
    B18_RC_MAX_FILE=${B18_RC_MAX_FILE:-$B18_PDK_ROOT/tech/star_rcxt/saed32nm_1p9m_Cmax.tluplus}
    B18_RC_MIN_FILE=${B18_RC_MIN_FILE:-$B18_PDK_ROOT/tech/star_rcxt/saed32nm_1p9m_Cmin.tluplus}
    B18_RC_MAP_FILE=${B18_RC_MAP_FILE:-$B18_PDK_ROOT/tech/star_rcxt/saed32nm_tf_itf_tluplus.map}

    for name in B18_RTL B18_TARGET_LIBRARY B18_DW_LIBRARY B18_LEF_FILE \
        B18_TECH_FILE B18_RC_MAX_FILE B18_RC_MIN_FILE B18_RC_MAP_FILE; do
        value=${!name-}
        if [[ -z $value ]]; then
            printf 'Missing %s. Set it in %s/setup.local.sh or export it first.\n' "$name" "$example_dir" >&2
            return 1
        fi
        if [[ $value != /* || ! -f $value || ! -r $value ]]; then
            printf '%s must be an absolute path to a readable file: %s\n' "$name" "$value" >&2
            return 1
        fi
    done

    B18_SCAN_CHAIN_COUNT=${B18_SCAN_CHAIN_COUNT-32}
    if [[ ! $B18_SCAN_CHAIN_COUNT =~ ^[1-9][0-9]*$ ]]; then
        printf 'B18_SCAN_CHAIN_COUNT must be a positive integer without leading zeros: %s\n' "$B18_SCAN_CHAIN_COUNT" >&2
        return 1
    fi

    B18_WORK_DIR=${B18_WORK_DIR:-$example_dir/work}
    if [[ $B18_WORK_DIR != /* ]]; then
        printf 'B18_WORK_DIR must be an absolute path: %s\n' "$B18_WORK_DIR" >&2
        return 1
    fi
    mkdir -p -- "$B18_WORK_DIR" || return 1

    B18_EXAMPLE_DIR=$example_dir
    export B18_EXAMPLE_DIR B18_WORK_DIR B18_SCAN_CHAIN_COUNT B18_PDK_ROOT \
        B18_RTL B18_TARGET_LIBRARY B18_DW_LIBRARY B18_LEF_FILE \
        B18_TECH_FILE B18_RC_MAX_FILE B18_RC_MIN_FILE B18_RC_MAP_FILE
}

if _b18_fc_dc_setup; then
    unset -f _b18_fc_dc_setup
else
    unset -f _b18_fc_dc_setup
    return 1
fi
