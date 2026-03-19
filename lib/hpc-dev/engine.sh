#!/usr/bin/env bash

hpc_dev_try_module_load() {
    local module_name="$1"
    [[ -n "${module_name}" ]] || return 1
    if [[ "$(type -t module 2>/dev/null || true)" == "function" ]]
    then
        module load "${module_name}" >/dev/null 2>&1 || return 1
        return 0
    fi
    return 1
}

hpc_dev_prepare_engine() {
    local request="${ENGINE_REQUEST:-auto}"

    if [[ "${request}" == "auto" ]]
    then
        if command -v apptainer >/dev/null 2>&1
        then
            ENGINE_CMD="apptainer"
        elif command -v singularity >/dev/null 2>&1
        then
            ENGINE_CMD="singularity"
        elif hpc_dev_try_module_load "${ENGINE_MODULE}"
        then
            if command -v apptainer >/dev/null 2>&1
            then
                ENGINE_CMD="apptainer"
            elif command -v singularity >/dev/null 2>&1
            then
                ENGINE_CMD="singularity"
            else
                hpc_dev_die "module '${ENGINE_MODULE}' loaded but no apptainer/singularity command found"
            fi
        else
            hpc_dev_die "could not resolve a container engine; set ENGINE_MODULE or use --engine"
        fi
    else
        if ! command -v "${request}" >/dev/null 2>&1
        then
            hpc_dev_try_module_load "${ENGINE_MODULE}" || true
        fi
        command -v "${request}" >/dev/null 2>&1 || hpc_dev_die "engine '${request}' not found"
        ENGINE_CMD="${request}"
    fi
}

hpc_dev_export_engine_env() {
    export APPTAINER_CACHEDIR="${CACHE_DIR}"
    export SINGULARITY_CACHEDIR="${CACHE_DIR}"
    export APPTAINER_TMPDIR="${ENGINE_TMP_DIR}"
    export SINGULARITY_TMPDIR="${ENGINE_TMP_DIR}"
    export TMPDIR="${ENGINE_TMP_DIR}"
}

hpc_dev_emit_engine_env_exports() {
    cat <<EOF
export APPTAINER_CACHEDIR="${CACHE_DIR}"
export SINGULARITY_CACHEDIR="${CACHE_DIR}"
export APPTAINER_TMPDIR="${ENGINE_TMP_DIR}"
export SINGULARITY_TMPDIR="${ENGINE_TMP_DIR}"
export TMPDIR="${ENGINE_TMP_DIR}"
EOF
}
