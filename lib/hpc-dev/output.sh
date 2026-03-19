#!/usr/bin/env bash

hpc_dev_print_plan() {
    cat <<EOF
Command: ${COMMAND}
Mode: ${MODE}
Image: ${IMAGE}
Engine: ${ENGINE_CMD}
Workspace: ${WORKSPACE_DIR} -> ${WORKSPACE_MOUNT}
Home mode: ${HOME_MODE}
Container home source: ${CONTAINER_HOME_SOURCE}
Real home mount: ${REAL_HOME_DIR} -> ${REAL_HOME_MOUNT}
Dev home mount: ${DEV_HOME_DIR} -> ${DEV_HOME_MOUNT}
Session ID: ${SESSION_ID}
Session dir: ${SESSION_DIR}
Cache dir: ${CACHE_DIR}
Engine tmp dir: ${ENGINE_TMP_DIR}
Container tmp dir: ${CONTAINER_TMP_DIR}
Login host: ${LOGIN_HOST}
Services: $(hpc_dev_join_by , "${SERVICES[@]}")
Groups: $(hpc_dev_join_by , "${GROUP_NAMES[@]-}")
Custom binds: $(hpc_dev_join_by , "${BINDS[@]-}")
EOF
}

hpc_dev_service_summary() {
    local service_name="$1"
    local env_file
    env_file="$(hpc_dev_service_file "${service_name}")"
    if hpc_dev_source_env_file "${env_file}"
    then
        if [[ "${service_name}" == "jupyter" ]]
        then
            printf '%s\n' "* ${service_name}: http://127.0.0.1:${PORT}?token=${TOKEN} (host ${HOST}:${PORT})"
        else
            printf '%s\n' "* ${service_name}: ${HOST}:${PORT}"
        fi
    else
        printf '%s\n' "* ${service_name}: pending"
    fi
}

hpc_dev_print_status() {
    echo "Session: ${SESSION_ID}"
    echo "Mode: ${MODE}"
    echo "Image: ${IMAGE}"
    if [[ "${MODE}" == "slurm" && -f "${SESSION_DIR}/slurm/job.env" ]]
    then
        hpc_dev_source_env_file "${SESSION_DIR}/slurm/job.env" || true
        echo "SLURM job: ${JOB_ID:-unknown}"
    fi
    echo "Workspace: ${WORKSPACE_DIR}"
    echo "Dev home: ${DEV_HOME_DIR}"
    echo "Session dir: ${SESSION_DIR}"
    echo "Cache dir: ${CACHE_DIR}"
    local service_name
    for service_name in "${SERVICES[@]}"
    do
        hpc_dev_service_summary "${service_name}"
    done
}

hpc_dev_print_ssh_command() {
    hpc_dev_source_env_file "$(hpc_dev_service_file sshd)" || hpc_dev_die "ssh service metadata not available"
    if [[ "${MODE}" == "local" ]]
    then
        echo "ssh -p ${PORT} ${USER}@127.0.0.1"
    else
        echo "ssh -J ${USER}@${LOGIN_HOST} ${USER}@${RAW_HOST} -p ${PORT}"
    fi
}

hpc_dev_print_tunnel_command() {
    local ssh_env
    ssh_env="$(hpc_dev_service_file sshd)"
    hpc_dev_source_env_file "${ssh_env}" || hpc_dev_die "ssh service metadata not available"
    local ssh_port="${PORT}"
    local ssh_host="${RAW_HOST:-${HOST}}"
    local forwards=()

    if [[ -f "$(hpc_dev_service_file jupyter)" ]]
    then
        hpc_dev_source_env_file "$(hpc_dev_service_file jupyter)"
        forwards+=("-L ${PORT}:127.0.0.1:${PORT}")
    fi
    if [[ -f "$(hpc_dev_service_file rstudio)" ]]
    then
        hpc_dev_source_env_file "$(hpc_dev_service_file rstudio)"
        forwards+=("-L ${PORT}:127.0.0.1:${PORT}")
    fi

    if [[ ${#forwards[@]} -eq 0 ]]
    then
        echo "No forwarded services are registered for session ${SESSION_ID}"
        return 0
    fi

    echo "ssh -NT -L ${ssh_port}:127.0.0.1:${ssh_port} $(hpc_dev_join_by ' ' "${forwards[@]}") -J ${USER}@${LOGIN_HOST} ${USER}@${ssh_host} -p ${ssh_port}"
}

hpc_dev_stop_session() {
    if [[ "${MODE}" == "local" ]]
    then
        hpc_dev_stop_local_session
    else
        hpc_dev_stop_slurm_session
    fi
}
