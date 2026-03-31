#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/hpc-service-lib.sh"

PORT=""
WORKSPACE=""
STATE_DIR=""
METADATA_FILE=""
PASSWORD_FILE=""
CONFIG_FILE=""
USER_DATA_DIR=""
EXTENSIONS_DIR=""
CACHE_HOME=""
BIND_ADDRESS="127.0.0.1"
CHILD_PID=""

hpc_service_codeserver_usage() {
    cat <<'EOF'
Usage:
  hpc-service-codeserver.sh --port PORT --workspace DIR --state-dir DIR --metadata-file FILE
    [--password-file FILE] [--config-file FILE] [--user-data-dir DIR]
    [--extensions-dir DIR] [--cache-home DIR] [--bind-address ADDR]
EOF
}

while [[ $# -gt 0 ]]
do
    case "$1" in
        --port) PORT="${2:-}"; shift 2 ;;
        --workspace) WORKSPACE="${2:-}"; shift 2 ;;
        --state-dir) STATE_DIR="${2:-}"; shift 2 ;;
        --metadata-file) METADATA_FILE="${2:-}"; shift 2 ;;
        --password-file) PASSWORD_FILE="${2:-}"; shift 2 ;;
        --config-file) CONFIG_FILE="${2:-}"; shift 2 ;;
        --user-data-dir) USER_DATA_DIR="${2:-}"; shift 2 ;;
        --extensions-dir) EXTENSIONS_DIR="${2:-}"; shift 2 ;;
        --cache-home) CACHE_HOME="${2:-}"; shift 2 ;;
        --bind-address) BIND_ADDRESS="${2:-}"; shift 2 ;;
        -h|--help) hpc_service_codeserver_usage; exit 0 ;;
        *) hpc_service_die "unknown option: $1" ;;
    esac
done

hpc_service_require_value --port "${PORT}"
hpc_service_require_value --workspace "${WORKSPACE}"
hpc_service_require_value --state-dir "${STATE_DIR}"
hpc_service_require_value --metadata-file "${METADATA_FILE}"

hpc_service_cleanup() {
    rm -f "${METADATA_FILE}" 2>/dev/null || true
    if [[ -n "${CHILD_PID}" ]]
    then
        kill "${CHILD_PID}" >/dev/null 2>&1 || true
    fi
}
trap hpc_service_cleanup EXIT HUP INT TERM

hpc_service_ensure_dir "${STATE_DIR}"
[[ -d "${WORKSPACE}" ]] || hpc_service_die "workspace not found: ${WORKSPACE}"

PASSWORD_FILE="${PASSWORD_FILE:-${STATE_DIR}/codeserver.password}"
CONFIG_FILE="${CONFIG_FILE:-${STATE_DIR}/config.yaml}"
USER_DATA_DIR="${USER_DATA_DIR:-${HOME}/.local/share/hpc-dev/code-server}"
EXTENSIONS_DIR="${EXTENSIONS_DIR:-${USER_DATA_DIR}/extensions}"
CACHE_HOME="${CACHE_HOME:-${HOME}/.cache/hpc-dev}"
CONFIG_DIR="$(dirname "${CONFIG_FILE}")"

hpc_service_ensure_dir "${CONFIG_DIR}"
hpc_service_ensure_dir "${USER_DATA_DIR}"
hpc_service_ensure_dir "${EXTENSIONS_DIR}"
hpc_service_ensure_dir "${CACHE_HOME}"

PASSWORD="$(hpc_service_random_token)"
printf '%s\n' "${PASSWORD}" > "${PASSWORD_FILE}"
chmod 600 "${PASSWORD_FILE}" || true
export PASSWORD
export XDG_CACHE_HOME="${CACHE_HOME}"

cat > "${CONFIG_FILE}" <<EOF
bind-addr: ${BIND_ADDRESS}:${PORT}
auth: password
password: ${PASSWORD}
cert: false
disable-telemetry: true
EOF

code-server \
    --config "${CONFIG_FILE}" \
    --user-data-dir "${USER_DATA_DIR}" \
    --extensions-dir "${EXTENSIONS_DIR}" \
    "${WORKSPACE}" &
CHILD_PID=$!

hpc_service_wait_for_port 127.0.0.1 "${PORT}" 30 || hpc_service_die "code-server did not become ready on port ${PORT}"

hpc_service_write_env_file "${METADATA_FILE}" \
    "SERVICE=codeserver" \
    "HOST=$(hpc_service_hostname)" \
    "PORT=${PORT}" \
    "BIND_ADDRESS=${BIND_ADDRESS}" \
    "PASSWORD=${PASSWORD}" \
    "URL=http://127.0.0.1:${PORT}/" \
    "STATUS=ready"

wait "${CHILD_PID}"
