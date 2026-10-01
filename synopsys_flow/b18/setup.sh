#!/usr/bin/env bash
# Source this file from Bash before running either b18 tool script.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    printf 'Source this file: source %s\n' "$0" >&2
    exit 1
fi

_b18_setup() {
    local example_dir name value
    example_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || return 1

    if [[ -f "$example_dir/setup.local.sh" ]]; then
        source "$example_dir/setup.local.sh" || return 1
    fi

    for name in B18_RTL B18_TARGET_LIBRARY B18_DW_LIBRARY B18_TMAX_LIBRARY; do
        value=${!name-}
        if [[ -z $value ]]; then
            printf 'Missing %s. Set it in %s/setup.local.sh or export it first.\n' "$name" "$example_dir" >&2
            return 1
        fi
        if [[ $value != /* || ! -f $value ]]; then
            printf '%s must be an absolute path to an existing file: %s\n' "$name" "$value" >&2
            return 1
        fi
        export "$name"
    done

    export B18_EXAMPLE_DIR="$example_dir"
    export B18_WORK_DIR="${B18_WORK_DIR:-$example_dir/work}"
    if [[ $B18_WORK_DIR != /* ]]; then
        printf 'B18_WORK_DIR must be an absolute path: %s\n' "$B18_WORK_DIR" >&2
        return 1
    fi
    mkdir -p -- "$B18_WORK_DIR" || return 1
}

if _b18_setup; then
    unset -f _b18_setup
else
    unset -f _b18_setup
    return 1
fi
