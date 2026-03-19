#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/hpc-service-lib.sh"

PORT=""
WORKSPACE=""
STATE_DIR=""
METADATA_FILE=""
TOKEN_FILE=""
BIND_ADDRESS="127.0.0.1"
CHILD_PID=""

hpc_service_jupyter_usage() {
    cat <<'EOF'
Usage:
  hpc-service-jupyter.sh --port PORT --workspace DIR --state-dir DIR --metadata-file FILE
    [--token-file FILE] [--bind-address ADDR]
EOF
}

while [[ $# -gt 0 ]]
do
    case "$1" in
        --port) PORT="${2:-}"; shift 2 ;;
        --workspace) WORKSPACE="${2:-}"; shift 2 ;;
        --state-dir) STATE_DIR="${2:-}"; shift 2 ;;
        --metadata-file) METADATA_FILE="${2:-}"; shift 2 ;;
        --token-file) TOKEN_FILE="${2:-}"; shift 2 ;;
        --bind-address) BIND_ADDRESS="${2:-}"; shift 2 ;;
        -h|--help) hpc_service_jupyter_usage; exit 0 ;;
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

TOKEN_FILE="${TOKEN_FILE:-${STATE_DIR}/jupyter.token}"
TOKEN="$(hpc_service_random_token)"
printf '%s\n' "${TOKEN}" > "${TOKEN_FILE}"
chmod 600 "${TOKEN_FILE}" || true

jupyter lab \
    --no-browser \
    --port="${PORT}" \
    --ServerApp.ip="${BIND_ADDRESS}" \
    --ServerApp.token="${TOKEN}" \
    --notebook-dir="${WORKSPACE}" &
CHILD_PID=$!

hpc_service_wait_for_port 127.0.0.1 "${PORT}" 30 || hpc_service_die "jupyter did not become ready on port ${PORT}"

hpc_service_write_env_file "${METADATA_FILE}" \
    "SERVICE=jupyter" \
    "HOST=$(hpc_service_hostname)" \
    "PORT=${PORT}" \
    "BIND_ADDRESS=${BIND_ADDRESS}" \
    "TOKEN=${TOKEN}" \
    "URL=http://127.0.0.1:${PORT}/lab?token=${TOKEN}" \
    "STATUS=ready"

wait "${CHILD_PID}"
