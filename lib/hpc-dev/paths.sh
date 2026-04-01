#!/usr/bin/env bash

hpc_dev_is_image_uri() {
    local image_value="$1"
    [[ "${image_value}" =~ ^[[:alpha:]][[:alnum:].+-]*:// ]]
}

hpc_dev_realpath() {
    local path_value="$1"
    if command -v realpath >/dev/null 2>&1
    then
        realpath "${path_value}"
    elif command -v grealpath >/dev/null 2>&1
    then
        grealpath "${path_value}"
    else
        local parent_dir
        parent_dir="$(cd "$(dirname "${path_value}")" && pwd -P)"
        printf '%s/%s\n' "${parent_dir}" "$(basename "${path_value}")"
    fi
}

hpc_dev_abs_path() {
    local path_value="$1"
    [[ -d "${path_value}" ]] || hpc_dev_die "path does not exist: ${path_value}"
    (cd "${path_value}" && pwd -P)
}

hpc_dev_abs_existing_path() {
    local path_value="$1"
    [[ -e "${path_value}" ]] || hpc_dev_die "path does not exist: ${path_value}"
    hpc_dev_realpath "${path_value}"
}

hpc_dev_safe_name() {
    local value="$1"
    printf '%s' "${value}" | tr -cs '[:alnum:]._:-' '-'
}

hpc_dev_resolve_paths() {
    WORKSPACE_DIR="$(hpc_dev_abs_path "${WORKSPACE}")"
    if hpc_dev_is_image_uri "${IMAGE}"
    then
        IMAGE_RESOLVED_TYPE="uri"
    else
        IMAGE="$(hpc_dev_abs_existing_path "${IMAGE}")"
        [[ -f "${IMAGE}" ]] || hpc_dev_die "image path is not a file: ${IMAGE}"
        IMAGE_RESOLVED_TYPE="path"
    fi
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
