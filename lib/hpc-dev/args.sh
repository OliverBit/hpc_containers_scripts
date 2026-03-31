#!/usr/bin/env bash

hpc_dev_die() {
    echo "Error: $*" >&2
    exit 1
}

hpc_dev_note() {
    echo "$*"
}

hpc_dev_join_by() {
    local delimiter="$1"
    shift || true
    local first=1
    local item
    for item in "$@"
    do
        if [[ ${first} -eq 1 ]]
        then
            printf '%s' "${item}"
            first=0
        else
            printf '%s%s' "${delimiter}" "${item}"
        fi
    done
}

hpc_dev_quote_args() {
    local item
    for item in "$@"
    do
        printf '%q ' "${item}"
    done
}

hpc_dev_service_requested() {
    local wanted="$1"
    local item
    for item in "${SERVICES[@]-}"
    do
        [[ -n "${item}" ]] || continue
        if [[ "${item}" == "${wanted}" ]]
        then
            return 0
        fi
    done
    return 1
}

hpc_dev_is_browser_service() {
    case "$1" in
        jupyter|rstudio|codeserver) return 0 ;;
        *) return 1 ;;
    esac
}

hpc_dev_count_browser_services() {
    local count=0
    local item
    for item in "${SERVICES[@]-}"
    do
        [[ -n "${item}" ]] || continue
        if hpc_dev_is_browser_service "${item}"
        then
            count=$((count + 1))
        fi
    done
    printf '%s\n' "${count}"
}

hpc_dev_browser_services_csv() {
    local services=()
    local item
    for item in "${SERVICES[@]-}"
    do
        [[ -n "${item}" ]] || continue
        if hpc_dev_is_browser_service "${item}"
        then
            services+=("${item}")
        fi
    done
    hpc_dev_join_by , "${services[@]-}"
}

hpc_dev_array_contains() {
    local wanted="$1"
    shift || true
    local item
    for item in "$@"
    do
        if [[ "${item}" == "${wanted}" ]]
        then
            return 0
        fi
    done
    return 1
}

hpc_dev_usage() {
    cat <<'EOF'
hpc-dev

Usage:
  hpc-dev plan  --mode local|slurm --image IMAGE --workspace PATH [options]
  hpc-dev start --mode local|slurm --image IMAGE --workspace PATH [options]
  hpc-dev status [SESSION_ID|--last]
  hpc-dev stop   [SESSION_ID|--last]
  hpc-dev ssh    [SESSION_ID|--last]
  hpc-dev tunnel [SESSION_ID|--last]

Common launch options:
  --mode MODE                 local or slurm
  --image IMAGE               image path or docker:// URI
  --workspace PATH            host workspace path
  --access MODE               ssh, browser, or both
  --service NAME              repeatable: sshd, jupyter, rstudio, codeserver
  --group NAME                repeatable group mount resolved from config
  --bind SPEC                 repeatable bind: host[:container[:opts]]
  --home-mode MODE            dev, real, or project
  --workspace-mount PATH      container workspace mount, default /workspace
  --real-home-mount PATH      container real home mount, default /host-home
  --dev-home-mount PATH       container dev home mount, default /dev-home
  --engine ENGINE             auto, apptainer, or singularity
  --helper-mode MODE          legacy or explicit
  --login-host HOST           SSH frontend for slurm mode
  --session-name NAME         friendly session name
  --cache-dir PATH            persistent image/cache directory
  --engine-tmp-dir PATH       engine build/unpack tmp directory
  --container-tmp-root PATH   per-session host tmp root bound to /tmp
  --ssh-port PORT|auto
  --jupyter-port PORT|auto
  --rstudio-port PORT|auto
  --codeserver-port PORT|auto

SLURM options:
  --partition NAME
  --time HH:MM:SS
  --cpus N
  --mem SIZE
  --email ADDRESS

Session lookup:
  --last                      use the last recorded session

Notes:
  * `ssh` and `tunnel` print the command to run; they do not execute it.
  * `plan` resolves mounts, paths, cache policy, and engine without launching.
EOF
}

hpc_dev_reset_options() {
    COMMAND=""
    MODE=""
    IMAGE=""
    WORKSPACE=""
    ACCESS_MODE="ssh"
    SERVICES=()
    GROUP_NAMES=()
    BINDS=()
    HOME_MODE="dev"
    WORKSPACE_MOUNT="/workspace"
    REAL_HOME_MOUNT="/host-home"
    DEV_HOME_MOUNT="/dev-home"
    SESSION_MOUNT="/hpc-dev-session"
    ENGINE_REQUEST="auto"
    HELPER_MODE="legacy"
    LOGIN_HOST=""
    SESSION_NAME=""
    SESSION_LOOKUP=""
    USE_LAST_SESSION="false"
    PARTITION=""
    TIME_LIMIT="08:00:00"
    CPUS="1"
    MEMORY="4G"
    EMAIL=""
    CACHE_DIR=""
    ENGINE_TMP_DIR=""
    CONTAINER_TMP_ROOT=""
    SSH_PORT_REQUEST="auto"
    JUPYTER_PORT_REQUEST="auto"
    RSTUDIO_PORT_REQUEST="auto"
    CODESERVER_PORT_REQUEST="auto"
    SSH_COMMAND_ARGS=()
}

hpc_dev_require_value() {
    local flag="$1"
    local value="${2:-}"
    [[ -n "${value}" ]] || hpc_dev_die "missing value for ${flag}"
}

hpc_dev_parse_launch_args() {
    while [[ $# -gt 0 ]]
    do
        case "$1" in
            --mode) MODE="${2:-}"; hpc_dev_require_value "$1" "${MODE}"; shift 2 ;;
            --image) IMAGE="${2:-}"; hpc_dev_require_value "$1" "${IMAGE}"; shift 2 ;;
            --workspace) WORKSPACE="${2:-}"; hpc_dev_require_value "$1" "${WORKSPACE}"; shift 2 ;;
            --access) ACCESS_MODE="${2:-}"; hpc_dev_require_value "$1" "${ACCESS_MODE}"; shift 2 ;;
            --service) SERVICES+=("${2:-}"); hpc_dev_require_value "$1" "${2:-}"; shift 2 ;;
            --group) GROUP_NAMES+=("${2:-}"); hpc_dev_require_value "$1" "${2:-}"; shift 2 ;;
            --bind) BINDS+=("${2:-}"); hpc_dev_require_value "$1" "${2:-}"; shift 2 ;;
            --home-mode) HOME_MODE="${2:-}"; hpc_dev_require_value "$1" "${HOME_MODE}"; shift 2 ;;
            --workspace-mount) WORKSPACE_MOUNT="${2:-}"; hpc_dev_require_value "$1" "${WORKSPACE_MOUNT}"; shift 2 ;;
            --real-home-mount) REAL_HOME_MOUNT="${2:-}"; hpc_dev_require_value "$1" "${REAL_HOME_MOUNT}"; shift 2 ;;
            --dev-home-mount) DEV_HOME_MOUNT="${2:-}"; hpc_dev_require_value "$1" "${DEV_HOME_MOUNT}"; shift 2 ;;
            --session-mount) SESSION_MOUNT="${2:-}"; hpc_dev_require_value "$1" "${SESSION_MOUNT}"; shift 2 ;;
            --engine) ENGINE_REQUEST="${2:-}"; hpc_dev_require_value "$1" "${ENGINE_REQUEST}"; shift 2 ;;
            --helper-mode) HELPER_MODE="${2:-}"; hpc_dev_require_value "$1" "${HELPER_MODE}"; shift 2 ;;
            --login-host) LOGIN_HOST="${2:-}"; hpc_dev_require_value "$1" "${LOGIN_HOST}"; shift 2 ;;
            --session-name) SESSION_NAME="${2:-}"; hpc_dev_require_value "$1" "${SESSION_NAME}"; shift 2 ;;
            --partition) PARTITION="${2:-}"; hpc_dev_require_value "$1" "${PARTITION}"; shift 2 ;;
            --time) TIME_LIMIT="${2:-}"; hpc_dev_require_value "$1" "${TIME_LIMIT}"; shift 2 ;;
            --cpus) CPUS="${2:-}"; hpc_dev_require_value "$1" "${CPUS}"; shift 2 ;;
            --mem) MEMORY="${2:-}"; hpc_dev_require_value "$1" "${MEMORY}"; shift 2 ;;
            --email) EMAIL="${2:-}"; hpc_dev_require_value "$1" "${EMAIL}"; shift 2 ;;
            --cache-dir) CACHE_DIR="${2:-}"; hpc_dev_require_value "$1" "${CACHE_DIR}"; shift 2 ;;
            --engine-tmp-dir) ENGINE_TMP_DIR="${2:-}"; hpc_dev_require_value "$1" "${ENGINE_TMP_DIR}"; shift 2 ;;
            --container-tmp-root) CONTAINER_TMP_ROOT="${2:-}"; hpc_dev_require_value "$1" "${CONTAINER_TMP_ROOT}"; shift 2 ;;
            --ssh-port) SSH_PORT_REQUEST="${2:-}"; hpc_dev_require_value "$1" "${SSH_PORT_REQUEST}"; shift 2 ;;
            --jupyter-port) JUPYTER_PORT_REQUEST="${2:-}"; hpc_dev_require_value "$1" "${JUPYTER_PORT_REQUEST}"; shift 2 ;;
            --rstudio-port) RSTUDIO_PORT_REQUEST="${2:-}"; hpc_dev_require_value "$1" "${RSTUDIO_PORT_REQUEST}"; shift 2 ;;
            --codeserver-port) CODESERVER_PORT_REQUEST="${2:-}"; hpc_dev_require_value "$1" "${CODESERVER_PORT_REQUEST}"; shift 2 ;;
            -h|--help) hpc_dev_usage; exit 0 ;;
            *) hpc_dev_die "unknown option for ${COMMAND}: $1" ;;
        esac
    done
}

hpc_dev_parse_session_args() {
    while [[ $# -gt 0 ]]
    do
        case "$1" in
            --last) USE_LAST_SESSION="true"; shift ;;
            --) shift; SSH_COMMAND_ARGS=("$@"); break ;;
            -h|--help) hpc_dev_usage; exit 0 ;;
            *)
                if [[ -z "${SESSION_LOOKUP}" ]]
                then
                    SESSION_LOOKUP="$1"
                    shift
                else
                    hpc_dev_die "unexpected extra argument: $1"
                fi
                ;;
        esac
    done
}

hpc_dev_validate_launch_args() {
    [[ -n "${MODE}" ]] || hpc_dev_die "--mode is required"
    [[ -n "${IMAGE}" ]] || hpc_dev_die "--image is required"
    [[ -n "${WORKSPACE}" ]] || hpc_dev_die "--workspace is required"

    case "${MODE}" in
        local|slurm) ;;
        *) hpc_dev_die "--mode must be local or slurm" ;;
    esac

    case "${ACCESS_MODE}" in
        ssh|browser|both) ;;
        *) hpc_dev_die "--access must be ssh, browser, or both" ;;
    esac

    case "${HOME_MODE}" in
        dev|real|project) ;;
        *) hpc_dev_die "--home-mode must be dev, real, or project" ;;
    esac

    case "${HELPER_MODE}" in
        legacy|explicit) ;;
        *) hpc_dev_die "--helper-mode must be legacy or explicit" ;;
    esac

    local validated_services=()
    local item
    for item in "${SERVICES[@]-}"
    do
        [[ -n "${item}" ]] || continue
        case "${item}" in
            sshd|jupyter|rstudio|codeserver) ;;
            *) hpc_dev_die "unsupported service '${item}'" ;;
        esac
        if ! hpc_dev_array_contains "${item}" "${validated_services[@]-}"
        then
            validated_services+=("${item}")
        fi
    done
    SERVICES=("${validated_services[@]-}")

    if [[ "${HELPER_MODE}" != "explicit" && "${ACCESS_MODE}" != "ssh" ]]
    then
        hpc_dev_die "--access ${ACCESS_MODE} requires --helper-mode explicit"
    fi

    if hpc_dev_service_requested "codeserver" && [[ "${HELPER_MODE}" != "explicit" ]]
    then
        hpc_dev_die "--service codeserver requires --helper-mode explicit"
    fi

    local browser_count
    browser_count="$(hpc_dev_count_browser_services)"
    local normalized_services=()

    case "${ACCESS_MODE}" in
        ssh)
            normalized_services=("sshd")
            for item in "${SERVICES[@]-}"
            do
                [[ -n "${item}" ]] || continue
                if [[ "${item}" != "sshd" ]]
                then
                    normalized_services+=("${item}")
                fi
            done
            ;;
        browser)
            if hpc_dev_service_requested "sshd"
            then
                hpc_dev_die "--access browser cannot be combined with --service sshd"
            fi
            [[ "${browser_count}" -gt 0 ]] || hpc_dev_die "--access browser requires at least one of jupyter, rstudio, or codeserver"
            normalized_services=("${SERVICES[@]-}")
            ;;
        both)
            [[ "${browser_count}" -gt 0 ]] || hpc_dev_die "--access both requires at least one of jupyter, rstudio, or codeserver"
            normalized_services=("sshd")
            for item in "${SERVICES[@]-}"
            do
                [[ -n "${item}" ]] || continue
                if [[ "${item}" != "sshd" ]]
                then
                    normalized_services+=("${item}")
                fi
            done
            ;;
    esac

    SERVICES=("${normalized_services[@]-}")
}

hpc_dev_main() {
    hpc_dev_reset_options
    COMMAND="${1:-}"
    [[ -n "${COMMAND}" ]] || { hpc_dev_usage; exit 1; }
    shift || true

    case "${COMMAND}" in
        plan|start)
            hpc_dev_parse_launch_args "$@"
            hpc_dev_load_config
            hpc_dev_validate_launch_args
            hpc_dev_prepare_engine
            hpc_dev_resolve_paths
            hpc_dev_build_bind_args
            if [[ "${COMMAND}" == "plan" ]]
            then
                hpc_dev_print_plan
            elif [[ "${MODE}" == "local" ]]
            then
                hpc_dev_prepare_session_tree
                hpc_dev_write_session_env
                hpc_dev_start_local
            else
                hpc_dev_prepare_session_tree
                hpc_dev_write_session_env
                hpc_dev_start_slurm
            fi
            ;;
        status|stop|ssh|tunnel)
            hpc_dev_parse_session_args "$@"
            hpc_dev_load_config
            hpc_dev_resolve_existing_session
            case "${COMMAND}" in
                status) hpc_dev_print_status ;;
                stop) hpc_dev_stop_session ;;
                ssh) hpc_dev_print_ssh_command ;;
                tunnel) hpc_dev_print_tunnel_command ;;
            esac
            ;;
        -h|--help|help)
            hpc_dev_usage
            ;;
        *)
            hpc_dev_die "unknown command: ${COMMAND}"
            ;;
    esac
}
