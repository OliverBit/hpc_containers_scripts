#!/usr/bin/env bash

hpc_dev_default_scratch_root() {
    if [[ -d "/scratch/${USER}" ]]
    then
        printf '%s\n' "/scratch/${USER}"
    else
        printf '%s\n' ""
    fi
}

hpc_dev_load_config() {
    local requested_login_host="${LOGIN_HOST:-}"
    local requested_cache_dir="${CACHE_DIR:-}"
    local requested_engine_tmp_dir="${ENGINE_TMP_DIR:-}"
    local requested_container_tmp_root="${CONTAINER_TMP_ROOT:-}"
    local requested_state_root="${STATE_ROOT:-}"
    local requested_dev_home_root="${DEV_HOME_ROOT:-}"
    local requested_group_root="${GROUP_ROOT:-}"
    local requested_engine_default="${ENGINE_DEFAULT:-}"
    local requested_engine_module="${ENGINE_MODULE:-}"
    local requested_helper_mode="${HELPER_MODE:-}"

    CONFIG_DIR="${HPC_DEV_CONFIG_DIR:-${HPC_DEV_HOST_HOME}/.config/hpc-dev}"
    CONFIG_FILE="${HPC_DEV_CONFIG_FILE:-${CONFIG_DIR}/config.env}"
    SCRATCH_ROOT="$(hpc_dev_default_scratch_root)"

    if [[ -f "${CONFIG_FILE}" ]]
    then
        # shellcheck source=/dev/null
        source "${CONFIG_FILE}"
    fi

    [[ -n "${requested_login_host}" ]] && LOGIN_HOST="${requested_login_host}"
    [[ -n "${requested_cache_dir}" ]] && CACHE_DIR="${requested_cache_dir}"
    [[ -n "${requested_engine_tmp_dir}" ]] && ENGINE_TMP_DIR="${requested_engine_tmp_dir}"
    [[ -n "${requested_container_tmp_root}" ]] && CONTAINER_TMP_ROOT="${requested_container_tmp_root}"
    [[ -n "${requested_state_root}" ]] && STATE_ROOT="${requested_state_root}"
    [[ -n "${requested_dev_home_root}" ]] && DEV_HOME_ROOT="${requested_dev_home_root}"
    [[ -n "${requested_group_root}" ]] && GROUP_ROOT="${requested_group_root}"
    [[ -n "${requested_engine_default}" ]] && ENGINE_DEFAULT="${requested_engine_default}"
    [[ -n "${requested_engine_module}" ]] && ENGINE_MODULE="${requested_engine_module}"
    [[ -n "${requested_helper_mode}" ]] && HELPER_MODE="${requested_helper_mode}"

    LOGIN_HOST="${HPC_DEV_LOGIN_HOST:-${LOGIN_HOST:-}}"
    ENGINE_DEFAULT="${HPC_DEV_ENGINE_DEFAULT:-${ENGINE_DEFAULT:-auto}}"
    ENGINE_MODULE="${HPC_DEV_ENGINE_MODULE:-${ENGINE_MODULE:-}}"
    HELPER_MODE="${HPC_DEV_HELPER_MODE:-${HELPER_MODE:-legacy}}"
    GROUP_ROOT="${HPC_DEV_GROUP_ROOT:-${GROUP_ROOT:-}}"
    DEFAULT_PARTITION="${DEFAULT_PARTITION:-cpu-interactive}"

    STATE_ROOT="${HPC_DEV_STATE_ROOT:-${STATE_ROOT:-${HPC_DEV_HOST_HOME}/.local/state/hpc-dev}}"
    DEV_HOME_ROOT="${HPC_DEV_DEV_HOME_ROOT:-${DEV_HOME_ROOT:-${HPC_DEV_HOST_HOME}/.local/share/hpc-dev/home}}"

    if [[ -z "${CACHE_DIR}" ]]
    then
        if [[ -n "${SCRATCH_ROOT}" ]]
        then
            CACHE_DIR="${SCRATCH_ROOT}/apptainer-cache"
        else
            CACHE_DIR="${STATE_ROOT}/cache/container"
        fi
    fi
    CACHE_DIR="${HPC_DEV_CACHE_DIR:-${CACHE_DIR}}"

    if [[ -z "${ENGINE_TMP_DIR}" ]]
    then
        if [[ -n "${SCRATCH_ROOT}" ]]
        then
            ENGINE_TMP_DIR="${SCRATCH_ROOT}/apptainer-tmp"
        else
            ENGINE_TMP_DIR="${STATE_ROOT}/tmp/engine"
        fi
    fi
    ENGINE_TMP_DIR="${HPC_DEV_ENGINE_TMP_DIR:-${ENGINE_TMP_DIR}}"

    if [[ -z "${CONTAINER_TMP_ROOT}" ]]
    then
        if [[ -n "${SCRATCH_ROOT}" ]]
        then
            CONTAINER_TMP_ROOT="${SCRATCH_ROOT}/hpc-dev-tmp"
        else
            CONTAINER_TMP_ROOT="${STATE_ROOT}/tmp/container"
        fi
    fi
    CONTAINER_TMP_ROOT="${HPC_DEV_CONTAINER_TMP_ROOT:-${CONTAINER_TMP_ROOT}}"

    PARTITION="${PARTITION:-${DEFAULT_PARTITION}}"
    ENGINE_REQUEST="${ENGINE_REQUEST:-${ENGINE_DEFAULT}}"
}

hpc_dev_upper_name() {
    printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_'
}

hpc_dev_group_path() {
    local group_name="$1"
    local var_name="GROUP_$(hpc_dev_upper_name "${group_name}")"
    local configured="${!var_name:-}"
    if [[ -n "${configured}" ]]
    then
        printf '%s\n' "${configured}"
    elif [[ -n "${GROUP_ROOT}" ]]
    then
        printf '%s\n' "${GROUP_ROOT}/${group_name}"
    else
        return 1
    fi
}
