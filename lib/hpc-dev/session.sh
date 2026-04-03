#!/usr/bin/env bash

hpc_dev_ensure_dir() {
    local dir_path="$1"
    mkdir -p "${dir_path}"
}

hpc_dev_lifecycle_file() {
    printf '%s/lifecycle.env\n' "${SESSION_DIR}"
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
    if hpc_dev_service_requested "sshd"
    then
        hpc_dev_prepare_ssh_nss_files
    fi
    printf '%s\n' "${SESSION_ID}" > "${LAST_SESSION_FILE}"
    hpc_dev_write_lifecycle_status "created" "session prepared"
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

hpc_dev_prepare_ssh_nss_files() {
    local ssh_dir="${SESSION_DIR}/ssh"
    local passwd_file="${ssh_dir}/passwd"
    local group_file="${ssh_dir}/group"
    local user_uid
    local user_gid
    local user_group
    local login_home

    user_uid="$(id -u)"
    user_gid="$(id -g)"
    user_group="$(id -gn 2>/dev/null || printf '%s' "${USER}")"
    login_home="${CONTAINER_HOME_SOURCE:-${DEV_HOME_DIR}}"

    cat > "${passwd_file}" <<EOF
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
${USER}:x:${user_uid}:${user_gid}:${USER}:${login_home}:/bin/bash
EOF

    cat > "${group_file}" <<EOF
root:x:0:
${user_group}:x:${user_gid}:${USER}
tty:x:${user_gid}:${USER}
nogroup:x:65534:
EOF
}

hpc_dev_write_lifecycle_status() {
    local state_value="$1"
    local detail_value="${2:-}"
    hpc_dev_write_env_file "$(hpc_dev_lifecycle_file)" \
        "STATE=${state_value}" \
        "DETAIL=${detail_value}" \
        "UPDATED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
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

hpc_dev_pid_is_live() {
    local pid_value="${1:-}"
    [[ -n "${pid_value}" ]] || return 1
    kill -0 "${pid_value}" >/dev/null 2>&1
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
    if [[ ! -d "${SESSION_DIR}" ]]
    then
        if [[ "${USE_LAST_SESSION}" == "true" || -z "${SESSION_LOOKUP}" ]]
        then
            hpc_dev_die "last recorded session '${SESSION_ID}' no longer exists; run 'hpc-dev cleanup' to refresh stale session pointers"
        fi
        hpc_dev_die "unknown session: ${SESSION_ID}"
    fi
    hpc_dev_source_env_file "${SESSION_DIR}/session.env" || hpc_dev_die "failed to load session metadata"
    hpc_dev_csv_to_array "${SERVICES_CSV:-${SERVICES:-}}" SERVICES
    hpc_dev_csv_to_array "${GROUP_NAMES_CSV:-${GROUP_NAMES:-}}" GROUP_NAMES
    hpc_dev_csv_to_array "${GROUP_BIND_PATHS_CSV:-${GROUP_BIND_PATHS:-}}" GROUP_BIND_PATHS
}

hpc_dev_slurm_squeue_state() {
    local job_id="$1"
    command -v squeue >/dev/null 2>&1 || return 1
    squeue -h -j "${job_id}" -o '%T' 2>/dev/null | awk 'NF {print; exit}'
}

hpc_dev_slurm_sacct_state() {
    local job_id="$1"
    command -v sacct >/dev/null 2>&1 || return 1
    sacct -n -X -j "${job_id}" -o State 2>/dev/null | awk '
        NF {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
            sub(/\+.*/, "", $0)
            print
            exit
        }
    '
}

hpc_dev_normalize_slurm_state() {
    local raw_state="$1"
    case "${raw_state}" in
        PENDING) printf '%s\n' "pending" ;;
        RUNNING|CONFIGURING|COMPLETING|SUSPENDED|RESIZING|STAGE_OUT|SIGNALING) printf '%s\n' "running" ;;
        COMPLETED|CANCELLED|FAILED|TIMEOUT|PREEMPTED|BOOT_FAIL|NODE_FAIL|OUT_OF_MEMORY|DEADLINE|REVOKED) printf '%s\n' "stopped" ;;
        *) printf '%s\n' "stopped" ;;
    esac
}

hpc_dev_normalize_slurm_detail() {
    local raw_state="$1"
    printf '%s\n' "${raw_state}" | tr '[:upper:]' '[:lower:]'
}

hpc_dev_local_session_has_live_pid() {
    local pid_file
    for pid_file in "${SESSION_DIR}"/pids/*.pid
    do
        [[ -f "${pid_file}" ]] || continue
        local pid_value
        pid_value="$(< "${pid_file}")"
        if hpc_dev_pid_is_live "${pid_value}"
        then
            return 0
        fi
    done
    return 1
}

hpc_dev_load_lifecycle_state() {
    local lifecycle_file
    lifecycle_file="$(hpc_dev_lifecycle_file)"
    if [[ -f "${lifecycle_file}" ]]
    then
        hpc_dev_source_env_file "${lifecycle_file}" || return 1
        return 0
    fi
    return 1
}

hpc_dev_refresh_local_session_state() {
    SESSION_RUNTIME_STATE=""
    SESSION_RUNTIME_DETAIL=""

    if hpc_dev_local_session_has_live_pid
    then
        SESSION_RUNTIME_STATE="running"
        SESSION_RUNTIME_DETAIL="local service pid active"
        return 0
    fi

    if hpc_dev_load_lifecycle_state && [[ "${STATE:-}" == "stopped" ]]
    then
        SESSION_RUNTIME_STATE="stopped"
        SESSION_RUNTIME_DETAIL="${DETAIL:-stopped}"
        return 0
    fi

    SESSION_RUNTIME_STATE="gone"
    SESSION_RUNTIME_DETAIL="local service is no longer running"
}

hpc_dev_refresh_slurm_session_state() {
    SESSION_RUNTIME_STATE=""
    SESSION_RUNTIME_DETAIL=""

    local job_env="${SESSION_DIR}/slurm/job.env"
    if ! hpc_dev_source_env_file "${job_env}"
    then
        if hpc_dev_load_lifecycle_state && [[ "${STATE:-}" == "stopped" ]]
        then
            SESSION_RUNTIME_STATE="stopped"
            SESSION_RUNTIME_DETAIL="${DETAIL:-stopped}"
        else
            SESSION_RUNTIME_STATE="gone"
            SESSION_RUNTIME_DETAIL="missing SLURM job metadata"
        fi
        return 0
    fi

    local raw_state=""
    raw_state="$(hpc_dev_slurm_squeue_state "${JOB_ID}")" || true
    if [[ -n "${raw_state}" ]]
    then
        SESSION_RUNTIME_STATE="$(hpc_dev_normalize_slurm_state "${raw_state}")"
        SESSION_RUNTIME_DETAIL="$(hpc_dev_normalize_slurm_detail "${raw_state}")"
        return 0
    fi

    if hpc_dev_load_lifecycle_state && [[ "${STATE:-}" == "stopped" ]]
    then
        SESSION_RUNTIME_STATE="stopped"
        SESSION_RUNTIME_DETAIL="${DETAIL:-stopped}"
        return 0
    fi

    raw_state="$(hpc_dev_slurm_sacct_state "${JOB_ID}")" || true
    if [[ -n "${raw_state}" ]]
    then
        SESSION_RUNTIME_STATE="$(hpc_dev_normalize_slurm_state "${raw_state}")"
        SESSION_RUNTIME_DETAIL="$(hpc_dev_normalize_slurm_detail "${raw_state}")"
        return 0
    fi

    SESSION_RUNTIME_STATE="gone"
    SESSION_RUNTIME_DETAIL="SLURM job ${JOB_ID} not found"
}

hpc_dev_refresh_session_state() {
    if [[ "${MODE}" == "slurm" ]]
    then
        hpc_dev_refresh_slurm_session_state
    else
        hpc_dev_refresh_local_session_state
    fi
}

hpc_dev_assert_running_session() {
    local action_label="$1"
    hpc_dev_refresh_session_state
    if [[ "${SESSION_RUNTIME_STATE}" != "running" ]]
    then
        hpc_dev_die "session ${SESSION_ID} is not running (${SESSION_RUNTIME_STATE}: ${SESSION_RUNTIME_DETAIL}); restart it or clean it up before using ${action_label}"
    fi
}

hpc_dev_cleanup_update_last_session() {
    if [[ "${CLEANUP_DRY_RUN:-false}" == "true" ]]
    then
        return 0
    fi
    local last_file="${LAST_SESSION_FILE:-${STATE_ROOT}/last-session}"
    [[ -f "${last_file}" ]] || return 0

    local latest_path=""
    latest_path="$(ls -1d "${STATE_ROOT}"/sessions/* 2>/dev/null | sort | tail -n 1)" || true
    if [[ -n "${latest_path}" && -d "${latest_path}" ]]
    then
        printf '%s\n' "$(basename "${latest_path}")" > "${last_file}"
    else
        rm -f "${last_file}"
    fi
}

hpc_dev_cleanup_matches_policy() {
    hpc_dev_refresh_session_state
    case "${SESSION_RUNTIME_STATE}" in
        gone) return 0 ;;
        stopped)
            [[ "${CLEANUP_ALL_STOPPED}" == "true" ]]
            return
            ;;
        *) return 1 ;;
    esac
}

hpc_dev_cleanup_remove_current_session() {
    local remove_session_dir="false"
    local remove_tmp_dir="false"

    if [[ -d "${SESSION_DIR}" ]]
    then
        remove_session_dir="true"
    fi
    if [[ -n "${CONTAINER_TMP_DIR:-}" && -d "${CONTAINER_TMP_DIR}" ]]
    then
        remove_tmp_dir="true"
    fi

    if [[ "${CLEANUP_DRY_RUN}" == "true" ]]
    then
        [[ "${remove_session_dir}" == "true" ]] && hpc_dev_note "Would remove session state: ${SESSION_DIR}"
        [[ "${remove_tmp_dir}" == "true" ]] && hpc_dev_note "Would remove container tmp: ${CONTAINER_TMP_DIR}"
        return 0
    fi

    [[ "${remove_session_dir}" == "true" ]] && rm -rf "${SESSION_DIR}"
    [[ "${remove_tmp_dir}" == "true" ]] && rm -rf "${CONTAINER_TMP_DIR}"
}

hpc_dev_cleanup_loaded_session() {
    local state_before detail_before
    hpc_dev_refresh_session_state
    state_before="${SESSION_RUNTIME_STATE}"
    detail_before="${SESSION_RUNTIME_DETAIL}"

    if ! hpc_dev_cleanup_matches_policy
    then
        hpc_dev_note "Skipping ${SESSION_ID}: state=${state_before} (${detail_before})"
        return 0
    fi

    hpc_dev_note "$( [[ "${CLEANUP_DRY_RUN}" == "true" ]] && printf 'Dry-run:' || printf 'Removing:' ) ${SESSION_ID} (state=${state_before}, detail=${detail_before})"
    hpc_dev_cleanup_remove_current_session
}

hpc_dev_cleanup_explicit_target() {
    SESSION_ID="${1}"
    SESSION_DIR="${STATE_ROOT}/sessions/${SESSION_ID}"

    if [[ ! -d "${SESSION_DIR}" ]]
    then
        hpc_dev_note "Session ${SESSION_ID} is already absent."
        hpc_dev_cleanup_update_last_session
        return 0
    fi

    if ! hpc_dev_source_env_file "${SESSION_DIR}/session.env"
    then
        hpc_dev_note "$( [[ "${CLEANUP_DRY_RUN}" == "true" ]] && printf 'Dry-run:' || printf 'Removing:' ) ${SESSION_ID} (state=gone, detail=missing session metadata)"
        if [[ "${CLEANUP_DRY_RUN}" != "true" ]]
        then
            rm -rf "${SESSION_DIR}"
        fi
        hpc_dev_cleanup_update_last_session
        return 0
    fi
    hpc_dev_csv_to_array "${SERVICES_CSV:-${SERVICES:-}}" SERVICES
    hpc_dev_csv_to_array "${GROUP_NAMES_CSV:-${GROUP_NAMES:-}}" GROUP_NAMES
    hpc_dev_csv_to_array "${GROUP_BIND_PATHS_CSV:-${GROUP_BIND_PATHS:-}}" GROUP_BIND_PATHS
    hpc_dev_cleanup_loaded_session
    hpc_dev_cleanup_update_last_session
}

hpc_dev_cleanup_all_sessions() {
    local session_path
    local found_any="false"
    for session_path in "${STATE_ROOT}"/sessions/*
    do
        [[ -d "${session_path}" ]] || continue
        found_any="true"
        hpc_dev_cleanup_explicit_target "$(basename "${session_path}")"
    done

    if [[ "${found_any}" != "true" ]]
    then
        hpc_dev_note "No session state directories were found."
    fi
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
