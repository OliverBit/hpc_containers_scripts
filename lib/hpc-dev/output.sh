#!/usr/bin/env bash

hpc_dev_print_plan() {
    cat <<EOF
Command: ${COMMAND}
Mode: ${MODE}
Image: ${IMAGE}
Engine: ${ENGINE_CMD}
Access: ${ACCESS_MODE}
Helper mode: ${HELPER_MODE}
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
Services: $(hpc_dev_join_by , "${SERVICES[@]-}")
Groups: $(hpc_dev_join_by , "${GROUP_NAMES[@]-}")
Custom binds: $(hpc_dev_join_by , "${BINDS[@]-}")
EOF
}

hpc_dev_browser_service_forward() {
    local service_name="$1"
    local env_file
    env_file="$(hpc_dev_service_file "${service_name}")"
    hpc_dev_source_env_file "${env_file}" || return 1
    local target_host="${RAW_HOST:-${HOST}}"
    printf '%s\n' "-L ${PORT}:${target_host}:${PORT}"
}

hpc_dev_print_browser_service_hints() {
    local service_name
    for service_name in "${SERVICES[@]-}"
    do
        [[ "${service_name}" == "sshd" ]] && continue
        local env_file
        env_file="$(hpc_dev_service_file "${service_name}")"
        if hpc_dev_source_env_file "${env_file}"
        then
            case "${service_name}" in
                jupyter)
                    echo "Jupyter: http://127.0.0.1:${PORT}/lab?token=${TOKEN}"
                    ;;
                rstudio)
                    echo "RStudio: http://127.0.0.1:${PORT}"
                    ;;
                codeserver)
                    echo "code-server: http://127.0.0.1:${PORT}/"
                    echo "code-server password: ${PASSWORD}"
                    ;;
            esac
        fi
    done
}

hpc_dev_service_summary() {
    local service_name="$1"
    local env_file
    env_file="$(hpc_dev_service_file "${service_name}")"
    if hpc_dev_source_env_file "${env_file}"
    then
        case "${service_name}" in
            sshd)
                printf '%s\n' "* ${service_name}: ${RAW_HOST:-${HOST}}:${PORT}"
                ;;
            jupyter)
                printf '%s\n' "* ${service_name}: http://127.0.0.1:${PORT}/lab?token=${TOKEN} (host ${RAW_HOST:-${HOST}}:${PORT})"
                ;;
            rstudio)
                printf '%s\n' "* ${service_name}: http://127.0.0.1:${PORT} (host ${RAW_HOST:-${HOST}}:${PORT})"
                ;;
            codeserver)
                printf '%s\n' "* ${service_name}: http://127.0.0.1:${PORT}/ (host ${RAW_HOST:-${HOST}}:${PORT}, password ${PASSWORD})"
                ;;
        esac
    else
        printf '%s\n' "* ${service_name}: pending"
    fi
}

hpc_dev_print_status() {
    echo "Session: ${SESSION_ID}"
    echo "Mode: ${MODE}"
    echo "Image: ${IMAGE}"
    echo "Access: ${ACCESS_MODE}"
    echo "Helper mode: ${HELPER_MODE}"
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
    for service_name in "${SERVICES[@]-}"
    do
        hpc_dev_service_summary "${service_name}"
    done
}

hpc_dev_print_ssh_command() {
    if [[ "${ACCESS_MODE}" == "browser" ]]
    then
        hpc_dev_die "session ${SESSION_ID} is browser-only; no SSH service is available"
    fi
    hpc_dev_source_env_file "$(hpc_dev_service_file sshd)" || hpc_dev_die "ssh service metadata not available"
    if [[ "${MODE}" == "local" ]]
    then
        echo "ssh -p ${PORT} ${USER}@127.0.0.1"
    else
        echo "ssh -J ${USER}@${LOGIN_HOST} ${USER}@${RAW_HOST:-${HOST}} -p ${PORT}"
    fi
}

hpc_dev_print_ssh_based_tunnel_command() {
    local print_hints="${1:-true}"
    local ssh_env
    ssh_env="$(hpc_dev_service_file sshd)"
    hpc_dev_source_env_file "${ssh_env}" || hpc_dev_die "ssh service metadata not available"
    local ssh_port="${PORT}"
    local ssh_host="${RAW_HOST:-${HOST}}"
    local forwards=()
    local service_name

    for service_name in "${SERVICES[@]-}"
    do
        [[ "${service_name}" == "sshd" ]] && continue
        if [[ -f "$(hpc_dev_service_file "${service_name}")" ]]
        then
            hpc_dev_source_env_file "$(hpc_dev_service_file "${service_name}")"
            forwards+=("-L ${PORT}:127.0.0.1:${PORT}")
        fi
    done

    if [[ ${#forwards[@]} -eq 0 ]]
    then
        echo "No browser services are registered for session ${SESSION_ID}"
        return 0
    fi

    echo "ssh -NT -L ${ssh_port}:127.0.0.1:${ssh_port} $(hpc_dev_join_by ' ' "${forwards[@]}") -J ${USER}@${LOGIN_HOST} ${USER}@${ssh_host} -p ${ssh_port}"
    if [[ "${print_hints}" == "true" ]]
    then
        hpc_dev_print_browser_service_hints
    fi
}

hpc_dev_print_browser_tunnel_command() {
    local print_hints="${1:-true}"
    local forwards=()
    local service_name
    for service_name in "${SERVICES[@]-}"
    do
        if hpc_dev_is_browser_service "${service_name}" && [[ -f "$(hpc_dev_service_file "${service_name}")" ]]
        then
            forwards+=("$(hpc_dev_browser_service_forward "${service_name}")")
        fi
    done

    if [[ ${#forwards[@]} -eq 0 ]]
    then
        echo "No browser services are registered for session ${SESSION_ID}"
        return 0
    fi

    echo "ssh -NT $(hpc_dev_join_by ' ' "${forwards[@]}") ${USER}@${LOGIN_HOST}"
    if [[ "${print_hints}" == "true" ]]
    then
        hpc_dev_print_browser_service_hints
    fi
}

hpc_dev_print_tunnel_command() {
    if [[ "${MODE}" == "local" ]]
    then
        echo "Local mode does not require SSH tunnels."
        if [[ "${ACCESS_MODE}" != "browser" ]] && [[ -f "$(hpc_dev_service_file sshd)" ]]
        then
            hpc_dev_print_ssh_command
        fi
        hpc_dev_print_browser_service_hints
        return 0
    fi

    case "${ACCESS_MODE}" in
        ssh)
            hpc_dev_print_ssh_based_tunnel_command
            ;;
        browser)
            hpc_dev_print_browser_tunnel_command
            ;;
        both)
            echo "Via container sshd:"
            hpc_dev_print_ssh_based_tunnel_command false
            echo
            echo "Via login host directly:"
            hpc_dev_print_browser_tunnel_command false
            echo
            hpc_dev_print_browser_service_hints
            ;;
    esac
}

hpc_dev_stop_session() {
    if [[ "${MODE}" == "local" ]]
    then
        hpc_dev_stop_local_session
    else
        hpc_dev_stop_slurm_session
    fi
}
