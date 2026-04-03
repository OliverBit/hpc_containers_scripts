#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/hpc-service-lib.sh"

PORT=""
STATE_DIR=""
METADATA_FILE=""
COOKIE_FILE=""
WORKSPACE=""
BIND_ADDRESS="127.0.0.1"
CHILD_PID=""

hpc_service_rstudio_usage() {
    cat <<'EOF'
Usage:
  hpc-service-rstudio.sh --port PORT --state-dir DIR --metadata-file FILE
    [--cookie-file FILE] [--workspace PATH] [--bind-address ADDR]
EOF
}

while [[ $# -gt 0 ]]
do
    case "$1" in
        --port) PORT="${2:-}"; shift 2 ;;
        --state-dir) STATE_DIR="${2:-}"; shift 2 ;;
        --metadata-file) METADATA_FILE="${2:-}"; shift 2 ;;
        --cookie-file) COOKIE_FILE="${2:-}"; shift 2 ;;
        --workspace) WORKSPACE="${2:-}"; shift 2 ;;
        --bind-address) BIND_ADDRESS="${2:-}"; shift 2 ;;
        -h|--help) hpc_service_rstudio_usage; exit 0 ;;
        *) hpc_service_die "unknown option: $1" ;;
    esac
done

hpc_service_require_value --port "${PORT}"
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
COOKIE_FILE="${COOKIE_FILE:-${STATE_DIR}/secure-cookie-key}"
WORKSPACE="${WORKSPACE:-${HOME}}"
if [[ ! -f "${COOKIE_FILE}" ]]
then
    printf '%s\n' "$(hpc_service_random_cookie)" > "${COOKIE_FILE}"
    chmod 600 "${COOKIE_FILE}" || true
fi

SERVER_DATA_DIR="${STATE_DIR}/server-data"
PROJECT_USER_DATA_DIR="${STATE_DIR}/project-user-data"
RSERVER_CONFIG="${STATE_DIR}/rserver.conf"
RSESSION_CONFIG="${STATE_DIR}/rsession.conf"

hpc_service_ensure_dir "${SERVER_DATA_DIR}"
hpc_service_ensure_dir "${PROJECT_USER_DATA_DIR}"

cat > "${RSESSION_CONFIG}" <<EOF
session-default-working-dir=${WORKSPACE}
session-project-user-data-dir=${PROJECT_USER_DATA_DIR}
session-allow-project-user-data-dir-override=0
EOF

cat > "${RSERVER_CONFIG}" <<EOF
server-user=${USER}
server-daemonize=0
server-working-dir=${WORKSPACE}
server-pid-file=${STATE_DIR}/rserver.pid
server-data-dir=${SERVER_DATA_DIR}
secure-cookie-key-file=${COOKIE_FILE}
www-address=${BIND_ADDRESS}
www-port=${PORT}
auth-none=1
server-project-sharing=0
rsession-config-file=${RSESSION_CONFIG}
EOF

/usr/lib/rstudio-server/bin/rserver --config-file "${RSERVER_CONFIG}" &
CHILD_PID=$!

hpc_service_wait_for_port 127.0.0.1 "${PORT}" 30 || hpc_service_die "rstudio did not become ready on port ${PORT}"

hpc_service_write_env_file "${METADATA_FILE}" \
    "SERVICE=rstudio" \
    "HOST=$(hpc_service_hostname)" \
    "PORT=${PORT}" \
    "BIND_ADDRESS=${BIND_ADDRESS}" \
    "URL=http://127.0.0.1:${PORT}" \
    "AUTH_MODE=none" \
    "STATUS=ready"

wait "${CHILD_PID}"
