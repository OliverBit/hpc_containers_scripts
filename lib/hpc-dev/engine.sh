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

hpc_dev_image_has_command() {
    local command_name="$1"
    hpc_dev_export_engine_env
    "${ENGINE_CMD}" exec "${IMAGE}" bash -lc "command -v ${command_name} >/dev/null 2>&1" >/dev/null 2>&1
}

hpc_dev_validate_explicit_helper_contract() {
    [[ "${HELPER_MODE}" == "explicit" ]] || return 0

    local required_commands=()
    local service_name
    for service_name in "${SERVICES[@]-}"
    do
        [[ -n "${service_name}" ]] || continue
        case "${service_name}" in
            sshd) required_commands+=("hpc-service-sshd.sh") ;;
            jupyter) required_commands+=("hpc-service-jupyter.sh") ;;
            codeserver) required_commands+=("hpc-service-codeserver.sh") ;;
        esac
    done

    local missing_commands=()
    local command_name
    for command_name in "${required_commands[@]-}"
    do
        if ! hpc_dev_image_has_command "${command_name}"
        then
            missing_commands+=("${command_name}")
        fi
    done

    if (( ${#missing_commands[@]} == 0 ))
    then
        return 0
    fi

    local image_name
    image_name="$(basename "${IMAGE}")"
    local helper_list
    helper_list="$(hpc_dev_join_by ', ' "${missing_commands[@]}")"

    if [[ "${image_name}" == "workbench-base-1.7.0.sif" ]]
    then
        hpc_dev_die "--helper-mode explicit requires ${helper_list} inside the image. ${image_name} is a legacy helper-contract image; use --helper-mode legacy."
    fi

    hpc_dev_die "--helper-mode explicit requires ${helper_list} inside the image. ${image_name} does not provide the explicit hpc-service-* helper contract; use a compatible owned image or switch to --helper-mode legacy."
}
