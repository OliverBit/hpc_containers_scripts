#!/usr/bin/env bash

hpc_dev_write_slurm_job_script() {
    local job_script="${SESSION_DIR}/slurm/job.sh"
    local quoted_binds
    quoted_binds="$(hpc_dev_quote_args "${BIND_ARGS[@]}")"
    local job_name
    if [[ -n "${SESSION_NAME}" ]]
    then
        job_name="$(hpc_dev_safe_name "${SESSION_NAME}")"
    else
        job_name="hpcdev-${USER}"
    fi

    cat > "${job_script}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

#SBATCH --job-name=${job_name}
#SBATCH --output=${SESSION_DIR}/logs/slurm-%j.log
#SBATCH --partition=${PARTITION}
#SBATCH --time=${TIME_LIMIT}
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=${CPUS}
#SBATCH --mem=${MEMORY}
EOF

    if [[ -n "${EMAIL}" ]]
    then
        cat >> "${job_script}" <<EOF
#SBATCH --mail-user=${EMAIL}
#SBATCH --mail-type=ALL
EOF
    fi

    cat >> "${job_script}" <<EOF

$(if [[ -n "${ENGINE_MODULE}" ]]; then printf 'module load %s\n' "${ENGINE_MODULE}"; fi)

$(hpc_dev_emit_engine_env_exports)

mkdir -p "${SESSION_DIR}/logs" "${SESSION_DIR}/services" "${SESSION_DIR}/pids" "${SESSION_DIR}/ssh"
mkdir -p "${CONTAINER_TMP_DIR}" "${ENGINE_TMP_DIR}" "${CACHE_DIR}"
touch "${OPEN_PORTS_FILE}"

USED_PORTS_FILE="${SESSION_DIR}/slurm/reserved-ports.txt"
: > "\${USED_PORTS_FILE}"

pick_port() {
    local candidate=""
    while true
    do
        candidate=\$((20000 + RANDOM % 20001))
        if grep -qx "\${candidate}" "\${USED_PORTS_FILE}" 2>/dev/null
        then
            continue
        fi
        if command -v ss >/dev/null 2>&1
        then
            if ss -tan | awk '{print \$4}' | grep -Eq "[:.]\\\${candidate}$"
            then
                continue
            fi
        fi
        printf '%s\n' "\${candidate}" >> "\${USED_PORTS_FILE}"
        printf '%s\n' "\${candidate}"
        return 0
    done
}

export DAT_FILE="${OPEN_PORTS_FILE}"
export SSH_CONFIG_PATH="${SESSION_DIR}/ssh/sshd"
export COOKIE_FILE="${SESSION_DIR}/ssh/rstudio-cookie"
export NOTEBOOK_DIR="${WORKSPACE_MOUNT}"
EOF

    if hpc_dev_service_requested "sshd"
    then
        if [[ "${SSH_PORT_REQUEST}" == "auto" ]]
        then
            echo 'export SSH_PORT="$(pick_port)"' >> "${job_script}"
        else
            echo "export SSH_PORT=\"${SSH_PORT_REQUEST}\"" >> "${job_script}"
        fi
        echo "\"${ENGINE_CMD}\" run ${quoted_binds}-H \"${CONTAINER_HOME_SOURCE}\" \"${IMAGE}\" run_sshd.sh >\"${SESSION_DIR}/logs/sshd.log\" 2>&1 &" >> "${job_script}"
    fi

    if hpc_dev_service_requested "jupyter"
    then
        if [[ "${JUPYTER_PORT_REQUEST}" == "auto" ]]
        then
            echo 'export JUPYTER_PORT="$(pick_port)"' >> "${job_script}"
        else
            echo "export JUPYTER_PORT=\"${JUPYTER_PORT_REQUEST}\"" >> "${job_script}"
        fi
        echo "\"${ENGINE_CMD}\" run ${quoted_binds}-H \"${CONTAINER_HOME_SOURCE}\" \"${IMAGE}\" run_jupyterlab.sh >\"${SESSION_DIR}/logs/jupyter.log\" 2>&1 &" >> "${job_script}"
    fi

    if hpc_dev_service_requested "rstudio"
    then
        cat >> "${job_script}" <<EOF
mkdir -p "${SESSION_DIR}/rstudio/var_lib" "${SESSION_DIR}/rstudio/var_run"
EOF
        local rstudio_bind_string
        rstudio_bind_string="${quoted_binds}$(hpc_dev_quote_args "-B" "${SESSION_DIR}/rstudio/var_lib:/var/lib/rstudio-server" "-B" "${SESSION_DIR}/rstudio/var_run:/var/run/rstudio-server")"
        if [[ "${RSTUDIO_PORT_REQUEST}" == "auto" ]]
        then
            echo 'export RSTUDIO_PORT="$(pick_port)"' >> "${job_script}"
        else
            echo "export RSTUDIO_PORT=\"${RSTUDIO_PORT_REQUEST}\"" >> "${job_script}"
        fi
        echo "\"${ENGINE_CMD}\" run ${rstudio_bind_string} -H \"${CONTAINER_HOME_SOURCE}\" \"${IMAGE}\" run_rstudioserver.sh >\"${SESSION_DIR}/logs/rstudio.log\" 2>&1 &" >> "${job_script}"
    fi

    cat >> "${job_script}" <<'EOF'
while true
do
    sleep 300
done
EOF

    chmod +x "${job_script}"
}

hpc_dev_start_slurm() {
    hpc_dev_write_slurm_job_script
    local submit_output
    submit_output="$(sbatch "${SESSION_DIR}/slurm/job.sh")" || hpc_dev_die "sbatch failed"
    local job_id
    job_id="$(sed -n 's/Submitted batch job \([0-9][0-9]*\)/\1/p' <<< "${submit_output}")"
    [[ -n "${job_id}" ]] || hpc_dev_die "failed to parse sbatch output: ${submit_output}"

    hpc_dev_write_env_file "${SESSION_DIR}/slurm/job.env" "JOB_ID=${job_id}" "SUBMIT_OUTPUT=${submit_output}"

    if hpc_dev_service_requested "sshd"
    then
        hpc_dev_wait_for_legacy_service "sshd" 120 || hpc_dev_die "sshd did not register in time"
    fi
    if hpc_dev_service_requested "jupyter"
    then
        hpc_dev_wait_for_legacy_service "jupyter" 120 || hpc_dev_die "jupyter did not register in time"
    fi
    if hpc_dev_service_requested "rstudio"
    then
        hpc_dev_wait_for_legacy_service "rstudio" 120 || hpc_dev_die "rstudio did not register in time"
    fi

    hpc_dev_note "Session started: ${SESSION_ID}"
    hpc_dev_print_status
}

hpc_dev_stop_slurm_session() {
    local job_env="${SESSION_DIR}/slurm/job.env"
    hpc_dev_source_env_file "${job_env}" || hpc_dev_die "missing SLURM job metadata for ${SESSION_ID}"
    scancel "${JOB_ID}" || hpc_dev_die "failed to cancel job ${JOB_ID}"
    hpc_dev_note "Stopped SLURM session: ${SESSION_ID}"
}
