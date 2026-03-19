#!/usr/bin/env bash

hpc_dev_service_requested() {
    local wanted="$1"
    local item
    for item in "${SERVICES[@]}"
    do
        if [[ "${item}" == "${wanted}" ]]
        then
            return 0
        fi
    done
    return 1
}

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

    hpc_dev_export_engine_env
    "${ENGINE_CMD}" run "${IMAGE}" true >"${SESSION_DIR}/logs/image-warmup.log" 2>&1 || true

    if hpc_dev_service_requested "sshd"
    then
        hpc_dev_run_legacy_service_local "sshd" "run_sshd.sh"
        hpc_dev_wait_for_legacy_service "sshd" 30 || hpc_dev_die "sshd did not register in time"
    fi
    if hpc_dev_service_requested "jupyter"
    then
        hpc_dev_run_legacy_service_local "jupyter" "run_jupyterlab.sh"
        hpc_dev_wait_for_legacy_service "jupyter" 30 || hpc_dev_die "jupyter did not register in time"
    fi
    if hpc_dev_service_requested "rstudio"
    then
        hpc_dev_run_legacy_service_local "rstudio" "run_rstudioserver.sh"
        hpc_dev_wait_for_legacy_service "rstudio" 30 || hpc_dev_die "rstudio did not register in time"
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
