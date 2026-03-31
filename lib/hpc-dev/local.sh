#!/usr/bin/env bash

hpc_dev_assign_local_ports() {
    if hpc_dev_service_requested "sshd"
    then
        SSH_PORT="${SSH_PORT_REQUEST}"
        [[ "${SSH_PORT}" != "auto" ]] || SSH_PORT="$(hpc_dev_pick_local_port)"
    fi
    if hpc_dev_service_requested "jupyter"
    then
        JUPYTER_PORT="${JUPYTER_PORT_REQUEST}"
        [[ "${JUPYTER_PORT}" != "auto" ]] || JUPYTER_PORT="$(hpc_dev_pick_local_port)"
    fi
    if hpc_dev_service_requested "rstudio"
    then
        RSTUDIO_PORT="${RSTUDIO_PORT_REQUEST}"
        [[ "${RSTUDIO_PORT}" != "auto" ]] || RSTUDIO_PORT="$(hpc_dev_pick_local_port)"
    fi
    if hpc_dev_service_requested "codeserver"
    then
        CODESERVER_PORT="${CODESERVER_PORT_REQUEST}"
        [[ "${CODESERVER_PORT}" != "auto" ]] || CODESERVER_PORT="$(hpc_dev_pick_local_port)"
    fi
}

hpc_dev_run_legacy_service_local() {
    local service_name="$1"
    local service_command="$2"
    local logfile="${SESSION_DIR}/logs/${service_name}.log"

    hpc_dev_export_engine_env
    export DAT_FILE="${OPEN_PORTS_FILE}"
    export SSH_CONFIG_PATH="${SESSION_DIR}/ssh/sshd"
    export COOKIE_FILE="${SESSION_DIR}/ssh/rstudio-cookie"
    export NOTEBOOK_DIR="${WORKSPACE_MOUNT}"

    "${ENGINE_CMD}" run "${BIND_ARGS[@]}" -H "${CONTAINER_HOME_SOURCE}" \
        "${IMAGE}" "${service_command}" >"${logfile}" 2>&1 &

    local pid=$!
    printf '%s\n' "${pid}" > "${SESSION_DIR}/pids/${service_name}.pid"
}

hpc_dev_explicit_helper_name() {
    case "$1" in
        sshd) printf '%s\n' "hpc-service-sshd.sh" ;;
        jupyter) printf '%s\n' "hpc-service-jupyter.sh" ;;
        rstudio) printf '%s\n' "hpc-service-rstudio.sh" ;;
        codeserver) printf '%s\n' "hpc-service-codeserver.sh" ;;
        *) return 1 ;;
    esac
}

hpc_dev_container_service_file() {
    local service_name="$1"
    printf '%s/services/%s.env\n' "${SESSION_MOUNT}" "${service_name}"
}

hpc_dev_container_service_state_dir() {
    local service_name="$1"
    printf '%s/services/%s.state\n' "${SESSION_MOUNT}" "${service_name}"
}

hpc_dev_prepare_explicit_service_dirs() {
    local service_name="$1"
    hpc_dev_ensure_dir "${SESSION_DIR}/services/${service_name}.state"
}

hpc_dev_run_explicit_service_local() {
    local service_name="$1"
    local helper_name
    helper_name="$(hpc_dev_explicit_helper_name "${service_name}")" || hpc_dev_die "unknown explicit service '${service_name}'"
    local logfile="${SESSION_DIR}/logs/${service_name}.log"
    local service_state_container
    service_state_container="$(hpc_dev_container_service_state_dir "${service_name}")"
    local metadata_container
    metadata_container="$(hpc_dev_container_service_file "${service_name}")"
    local helper_args=()

    hpc_dev_prepare_explicit_service_dirs "${service_name}"

    case "${service_name}" in
        sshd)
            helper_args=(
                --port "${SSH_PORT}"
                --state-dir "${service_state_container}"
                --metadata-file "${metadata_container}"
                --authorized-keys-file "${DEV_HOME_MOUNT}/.ssh/authorized_keys"
                --host-keys-dir "${SESSION_MOUNT}/ssh/hostkeys"
                --bind-address "0.0.0.0"
            )
            ;;
        jupyter)
            helper_args=(
                --port "${JUPYTER_PORT}"
                --workspace "${WORKSPACE_MOUNT}"
                --state-dir "${service_state_container}"
                --metadata-file "${metadata_container}"
                --token-file "${service_state_container}/jupyter.token"
                --bind-address "127.0.0.1"
            )
            ;;
        rstudio)
            helper_args=(
                --port "${RSTUDIO_PORT}"
                --state-dir "${service_state_container}"
                --metadata-file "${metadata_container}"
                --cookie-file "${service_state_container}/secure-cookie-key"
                --bind-address "127.0.0.1"
            )
            ;;
        codeserver)
            helper_args=(
                --port "${CODESERVER_PORT}"
                --workspace "${WORKSPACE_MOUNT}"
                --state-dir "${service_state_container}"
                --metadata-file "${metadata_container}"
                --password-file "${service_state_container}/codeserver.password"
                --config-file "${service_state_container}/config.yaml"
                --user-data-dir "${DEV_HOME_MOUNT}/.local/share/hpc-dev/code-server"
                --extensions-dir "${DEV_HOME_MOUNT}/.local/share/hpc-dev/code-server/extensions"
                --cache-home "${DEV_HOME_MOUNT}/.cache/hpc-dev"
                --bind-address "127.0.0.1"
            )
            ;;
    esac

    hpc_dev_export_engine_env
    "${ENGINE_CMD}" exec "${BIND_ARGS[@]}" -H "${CONTAINER_HOME_SOURCE}" \
        "${IMAGE}" "${helper_name}" "${helper_args[@]}" >"${logfile}" 2>&1 &

    local pid=$!
    printf '%s\n' "${pid}" > "${SESSION_DIR}/pids/${service_name}.pid"
}

hpc_dev_start_local() {
    hpc_dev_assign_local_ports

    if hpc_dev_service_requested "sshd"
    then
        export SSH_PORT
    fi
    if hpc_dev_service_requested "jupyter"
    then
        export JUPYTER_PORT
    fi
    if hpc_dev_service_requested "rstudio"
    then
        export RSTUDIO_PORT
        hpc_dev_ensure_dir "${SESSION_DIR}/rstudio/var_lib"
        hpc_dev_ensure_dir "${SESSION_DIR}/rstudio/var_run"
        BIND_ARGS+=("-B" "${SESSION_DIR}/rstudio/var_lib:/var/lib/rstudio-server")
        BIND_ARGS+=("-B" "${SESSION_DIR}/rstudio/var_run:/var/run/rstudio-server")
    fi
    if hpc_dev_service_requested "codeserver"
    then
        export CODESERVER_PORT
    fi

    hpc_dev_export_engine_env
    "${ENGINE_CMD}" run "${IMAGE}" true >"${SESSION_DIR}/logs/image-warmup.log" 2>&1 || true

    if hpc_dev_service_requested "sshd"
    then
        if [[ "${HELPER_MODE}" == "explicit" ]]
        then
            hpc_dev_run_explicit_service_local "sshd"
        else
            hpc_dev_run_legacy_service_local "sshd" "run_sshd.sh"
        fi
        hpc_dev_wait_for_service "sshd" 30 || hpc_dev_die "sshd did not register in time"
    fi
    if hpc_dev_service_requested "jupyter"
    then
        if [[ "${HELPER_MODE}" == "explicit" ]]
        then
            hpc_dev_run_explicit_service_local "jupyter"
        else
            hpc_dev_run_legacy_service_local "jupyter" "run_jupyterlab.sh"
        fi
        hpc_dev_wait_for_service "jupyter" 30 || hpc_dev_die "jupyter did not register in time"
    fi
    if hpc_dev_service_requested "rstudio"
    then
        if [[ "${HELPER_MODE}" == "explicit" ]]
        then
            hpc_dev_run_explicit_service_local "rstudio"
        else
            hpc_dev_run_legacy_service_local "rstudio" "run_rstudioserver.sh"
        fi
        hpc_dev_wait_for_service "rstudio" 30 || hpc_dev_die "rstudio did not register in time"
    fi
    if hpc_dev_service_requested "codeserver"
    then
        if [[ "${HELPER_MODE}" == "explicit" ]]
        then
            hpc_dev_run_explicit_service_local "codeserver"
        else
            hpc_dev_die "codeserver is supported only with --helper-mode explicit"
        fi
        hpc_dev_wait_for_service "codeserver" 30 || hpc_dev_die "codeserver did not register in time"
    fi

    hpc_dev_note "Session started: ${SESSION_ID}"
    hpc_dev_print_status
}

hpc_dev_stop_local_session() {
    local pid_file
    for pid_file in "${SESSION_DIR}"/pids/*.pid
    do
        [[ -f "${pid_file}" ]] || continue
        local pid
        pid="$(< "${pid_file}")"
        kill "${pid}" >/dev/null 2>&1 || true
    done
    hpc_dev_note "Stopped local session: ${SESSION_ID}"
}
