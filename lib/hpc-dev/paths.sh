#!/usr/bin/env bash

hpc_dev_abs_path() {
    local path_value="$1"
    [[ -d "${path_value}" ]] || hpc_dev_die "path does not exist: ${path_value}"
    (cd "${path_value}" && pwd -P)
}

hpc_dev_safe_name() {
    local value="$1"
    printf '%s' "${value}" | tr -cs '[:alnum:]._-:' '-'
}

hpc_dev_resolve_paths() {
    WORKSPACE_DIR="$(hpc_dev_abs_path "${WORKSPACE}")"
    REAL_HOME_DIR="${HPC_DEV_HOST_HOME}"
    DEV_HOME_DIR="${DEV_HOME_ROOT}/default"
    CURRENT_TS="$(date '+%Y%m%dT%H%M%S')"

    if [[ -n "${SESSION_NAME}" ]]
    then
        SESSION_SLUG="$(hpc_dev_safe_name "${SESSION_NAME}")"
    else
        SESSION_SLUG="$(hpc_dev_safe_name "$(basename "${WORKSPACE_DIR}")")"
    fi

    SESSION_ID="${CURRENT_TS}-${USER}-${SESSION_SLUG}-$$"
    SESSION_DIR="${STATE_ROOT}/sessions/${SESSION_ID}"
    LAST_SESSION_FILE="${STATE_ROOT}/last-session"
    OPEN_PORTS_FILE="${SESSION_DIR}/services/open_ports.dat"
    CONTAINER_TMP_DIR="${CONTAINER_TMP_ROOT}/${SESSION_ID}"

    case "${HOME_MODE}" in
        dev) CONTAINER_HOME_SOURCE="${DEV_HOME_DIR}" ;;
        real) CONTAINER_HOME_SOURCE="${REAL_HOME_DIR}" ;;
        project) CONTAINER_HOME_SOURCE="${WORKSPACE_DIR}" ;;
    esac

    [[ -n "${LOGIN_HOST}" ]] || LOGIN_HOST="$(hostname -f 2>/dev/null || hostname)"
}
