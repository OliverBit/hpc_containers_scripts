#!/usr/bin/env bash

hpc_dev_ensure_dir() {
    local dir_path="$1"
    mkdir -p "${dir_path}"
}

hpc_dev_write_env_file() {
    local target_path="$1"
    shift
    local tmp_path="${target_path}.tmp"
    : > "${tmp_path}"
    local line
    for line in "$@"
    do
        if [[ "${line}" == *=* ]]
        then
            local key="${line%%=*}"
            local value="${line#*=}"
            printf '%s=%q\n' "${key}" "${value}" >> "${tmp_path}"
        else
            printf '%s\n' "${line}" >> "${tmp_path}"
        fi
    done
    mv "${tmp_path}" "${target_path}"
}

hpc_dev_prepare_session_tree() {
    hpc_dev_ensure_dir "${STATE_ROOT}"
    hpc_dev_ensure_dir "${DEV_HOME_DIR}"
    hpc_dev_ensure_dir "${CACHE_DIR}"
    hpc_dev_ensure_dir "${ENGINE_TMP_DIR}"
    hpc_dev_ensure_dir "${SESSION_DIR}"
    hpc_dev_ensure_dir "${SESSION_DIR}/logs"
    hpc_dev_ensure_dir "${SESSION_DIR}/services"
    hpc_dev_ensure_dir "${SESSION_DIR}/slurm"
    hpc_dev_ensure_dir "${SESSION_DIR}/pids"
    hpc_dev_ensure_dir "${SESSION_DIR}/ssh"
    hpc_dev_ensure_dir "${DEV_HOME_DIR}/.ssh"
    chmod 700 "${DEV_HOME_DIR}/.ssh" || true

    if [[ "${MODE}" == "local" ]]
    then
        hpc_dev_ensure_dir "${CONTAINER_TMP_DIR}"
    fi

    hpc_dev_sync_authorized_keys
    printf '%s\n' "${SESSION_ID}" > "${LAST_SESSION_FILE}"
}

hpc_dev_sync_authorized_keys() {
    local source_auth="${REAL_HOME_DIR}/.ssh/authorized_keys"
    local target_auth="${DEV_HOME_DIR}/.ssh/authorized_keys"
    local tmp_auth="${target_auth}.tmp"
    local auth_inputs=()

    if [[ -f "${source_auth}" ]]
    then
        auth_inputs+=("${source_auth}")
        if [[ -f "${target_auth}" ]]
        then
            auth_inputs+=("${target_auth}")
        fi
        cat "${auth_inputs[@]}" | awk '!seen[$0]++' > "${tmp_auth}"
        mv "${tmp_auth}" "${target_auth}"
        chmod 600 "${target_auth}" || true
    elif [[ ! -f "${target_auth}" ]]
    then
        : > "${target_auth}"
        chmod 600 "${target_auth}" || true
    fi
}

hpc_dev_write_session_env() {
    hpc_dev_write_env_file "${SESSION_DIR}/session.env" \
        "SESSION_ID=${SESSION_ID}" \
        "SESSION_DIR=${SESSION_DIR}" \
        "MODE=${MODE}" \
        "IMAGE=${IMAGE}" \
        "ENGINE_CMD=${ENGINE_CMD}" \
        "LOGIN_HOST=${LOGIN_HOST}" \
        "ACCESS_MODE=${ACCESS_MODE}" \
        "WORKSPACE_DIR=${WORKSPACE_DIR}" \
        "WORKSPACE_MOUNT=${WORKSPACE_MOUNT}" \
        "REAL_HOME_DIR=${REAL_HOME_DIR}" \
        "REAL_HOME_MOUNT=${REAL_HOME_MOUNT}" \
        "DEV_HOME_DIR=${DEV_HOME_DIR}" \
        "DEV_HOME_MOUNT=${DEV_HOME_MOUNT}" \
        "SESSION_MOUNT=${SESSION_MOUNT}" \
        "HOME_MODE=${HOME_MODE}" \
        "HELPER_MODE=${HELPER_MODE}" \
        "CONTAINER_HOME_SOURCE=${CONTAINER_HOME_SOURCE}" \
        "CACHE_DIR=${CACHE_DIR}" \
        "ENGINE_TMP_DIR=${ENGINE_TMP_DIR}" \
        "CONTAINER_TMP_DIR=${CONTAINER_TMP_DIR}" \
        "OPEN_PORTS_FILE=${OPEN_PORTS_FILE}" \
        "PARTITION=${PARTITION}" \
        "TIME_LIMIT=${TIME_LIMIT}" \
        "CPUS=${CPUS}" \
        "MEMORY=${MEMORY}" \
        "EMAIL=${EMAIL}" \
        "SERVICES_CSV=$(hpc_dev_join_by , "${SERVICES[@]-}")" \
        "BROWSER_SERVICES_CSV=$(hpc_dev_browser_services_csv)" \
        "GROUP_NAMES_CSV=$(hpc_dev_join_by , "${GROUP_NAMES[@]-}")" \
        "GROUP_BIND_PATHS_CSV=$(hpc_dev_join_by , "${GROUP_BIND_PATHS[@]:-}")" \
        "SSH_PORT_REQUEST=${SSH_PORT_REQUEST}" \
        "JUPYTER_PORT_REQUEST=${JUPYTER_PORT_REQUEST}" \
        "RSTUDIO_PORT_REQUEST=${RSTUDIO_PORT_REQUEST}" \
        "CODESERVER_PORT_REQUEST=${CODESERVER_PORT_REQUEST}"
}

hpc_dev_source_env_file() {
    local env_file="$1"
    [[ -f "${env_file}" ]] || return 1
    # shellcheck disable=SC1090
    source "${env_file}"
}

hpc_dev_csv_to_array() {
    local csv_value="${1:-}"
    local array_name="$2"
    local old_ifs="${IFS}"
    IFS=','
    # shellcheck disable=SC2206
    local items=(${csv_value})
    IFS="${old_ifs}"
    if [[ -z "${csv_value}" ]]
    then
        eval "${array_name}=()"
    else
        eval "${array_name}=(\"\${items[@]}\")"
    fi
}

hpc_dev_resolve_existing_session() {
    local session_id="${SESSION_LOOKUP}"
    if [[ "${USE_LAST_SESSION}" == "true" || -z "${session_id}" ]]
    then
        [[ -f "${LAST_SESSION_FILE:-${STATE_ROOT}/last-session}" ]] || hpc_dev_die "no last session recorded"
        session_id="$(< "${LAST_SESSION_FILE:-${STATE_ROOT}/last-session}")"
    fi
    SESSION_ID="${session_id}"
    SESSION_DIR="${STATE_ROOT}/sessions/${SESSION_ID}"
    [[ -d "${SESSION_DIR}" ]] || hpc_dev_die "unknown session: ${SESSION_ID}"
    hpc_dev_source_env_file "${SESSION_DIR}/session.env" || hpc_dev_die "failed to load session metadata"
    hpc_dev_csv_to_array "${SERVICES_CSV:-${SERVICES:-}}" SERVICES
    hpc_dev_csv_to_array "${GROUP_NAMES_CSV:-${GROUP_NAMES:-}}" GROUP_NAMES
    hpc_dev_csv_to_array "${GROUP_BIND_PATHS_CSV:-${GROUP_BIND_PATHS:-}}" GROUP_BIND_PATHS
}

hpc_dev_pick_local_port() {
    local candidate=""
    while true
    do
        candidate="$((20000 + RANDOM % 20001))"
        if command -v nc >/dev/null 2>&1
        then
            if ! nc -z 127.0.0.1 "${candidate}" >/dev/null 2>&1
            then
                printf '%s\n' "${candidate}"
                return 0
            fi
        else
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
}
