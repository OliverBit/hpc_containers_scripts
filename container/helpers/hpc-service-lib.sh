#!/usr/bin/env bash

set -euo pipefail

hpc_service_die() {
    echo "Error: $*" >&2
    exit 1
}

hpc_service_require_value() {
    local flag="$1"
    local value="${2:-}"
    [[ -n "${value}" ]] || hpc_service_die "missing value for ${flag}"
}

hpc_service_ensure_dir() {
    mkdir -p "$1"
}

hpc_service_write_env_file() {
    local target_path="$1"
    shift
    local tmp_path="${target_path}.tmp"
    : > "${tmp_path}"
    local line
    for line in "$@"
    do
        printf '%s\n' "${line}" >> "${tmp_path}"
    done
    mv "${tmp_path}" "${target_path}"
}

hpc_service_wait_for_port() {
    local host="${1:-127.0.0.1}"
    local port="${2:-}"
    local timeout_seconds="${3:-30}"
    local waited=0
    while [[ ${waited} -lt ${timeout_seconds} ]]
    do
        if command -v nc >/dev/null 2>&1
        then
            if nc -z "${host}" "${port}" >/dev/null 2>&1
            then
                return 0
            fi
        else
            if bash -c "exec 3<>/dev/tcp/${host}/${port}" >/dev/null 2>&1
            then
                return 0
            fi
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}

hpc_service_random_token() {
    openssl rand -hex 24
}

hpc_service_random_cookie() {
    openssl rand -base64 48 | tr -d '\n'
}

hpc_service_hostname() {
    hostname -f 2>/dev/null || hostname
}
