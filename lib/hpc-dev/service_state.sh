#!/usr/bin/env bash

hpc_dev_service_file() {
    local service_name="$1"
    printf '%s/services/%s.env\n' "${SESSION_DIR}" "${service_name}"
}

hpc_dev_legacy_service_label() {
    case "$1" in
        sshd) printf '%s\n' "sshd" ;;
        jupyter) printf '%s\n' "jupyter" ;;
        rstudio) printf '%s\n' "rstudio-server" ;;
        *) return 1 ;;
    esac
}

hpc_dev_capture_legacy_service() {
    local service_name="$1"
    local service_label
    service_label="$(hpc_dev_legacy_service_label "${service_name}")" || return 1
    [[ -f "${OPEN_PORTS_FILE}" ]] || return 1

    local raw_line
    raw_line="$(awk -v label="${service_label}" '$1 == label {line=$0} END {print line}' "${OPEN_PORTS_FILE}")"
    [[ -n "${raw_line}" ]] || return 1

    local host_port
    host_port="$(awk '{print $3}' <<< "${raw_line}")"
    local raw_host="${host_port%%:*}"
    local port="${host_port##*:}"
    local connect_host="${raw_host}"
    local token=""
    if [[ "${MODE}" == "local" ]]
    then
        connect_host="127.0.0.1"
    fi
    if [[ "${service_name}" == "jupyter" ]]
    then
        token="$(awk '{print $4}' <<< "${raw_line}")"
        token="${token#token=}"
    fi

    local service_env
    service_env="$(hpc_dev_service_file "${service_name}")"
    hpc_dev_write_env_file "${service_env}" \
        "SERVICE=${service_name}" \
        "LABEL=${service_label}" \
        "MODE=${MODE}" \
        "HOST=${connect_host}" \
        "RAW_HOST=${raw_host}" \
        "PORT=${port}" \
        "TOKEN=${token}" \
        "STATUS=ready"
}

hpc_dev_wait_for_legacy_service() {
    local service_name="$1"
    local timeout_seconds="${2:-60}"
    local waited=0
    while [[ ${waited} -lt ${timeout_seconds} ]]
    do
        if hpc_dev_capture_legacy_service "${service_name}"
        then
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
    done
    return 1
}
