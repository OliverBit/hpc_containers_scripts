#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/hpc-service-lib.sh"

PORT=""
STATE_DIR=""
METADATA_FILE=""
AUTHORIZED_KEYS_FILE=""
HOST_KEYS_DIR=""
BIND_ADDRESS="0.0.0.0"
CHILD_PID=""
AUTH_KEYS_DIR=""

hpc_service_sshd_usage() {
    cat <<'EOF'
Usage:
  hpc-service-sshd.sh --port PORT --state-dir DIR --metadata-file FILE \
    --authorized-keys-file FILE --host-keys-dir DIR [--bind-address ADDR]
EOF
}

while [[ $# -gt 0 ]]
do
    case "$1" in
        --port) PORT="${2:-}"; shift 2 ;;
        --state-dir) STATE_DIR="${2:-}"; shift 2 ;;
        --metadata-file) METADATA_FILE="${2:-}"; shift 2 ;;
        --authorized-keys-file) AUTHORIZED_KEYS_FILE="${2:-}"; shift 2 ;;
        --host-keys-dir) HOST_KEYS_DIR="${2:-}"; shift 2 ;;
        --bind-address) BIND_ADDRESS="${2:-}"; shift 2 ;;
        -h|--help) hpc_service_sshd_usage; exit 0 ;;
        *) hpc_service_die "unknown option: $1" ;;
    esac
done

hpc_service_require_value --port "${PORT}"
hpc_service_require_value --state-dir "${STATE_DIR}"
hpc_service_require_value --metadata-file "${METADATA_FILE}"
hpc_service_require_value --authorized-keys-file "${AUTHORIZED_KEYS_FILE}"
hpc_service_require_value --host-keys-dir "${HOST_KEYS_DIR}"

hpc_service_cleanup() {
    rm -f "${METADATA_FILE}" 2>/dev/null || true
    if [[ -n "${AUTH_KEYS_DIR}" ]]
    then
        rm -rf "${AUTH_KEYS_DIR}" 2>/dev/null || true
    fi
    if [[ -n "${CHILD_PID}" ]]
    then
        kill "${CHILD_PID}" >/dev/null 2>&1 || true
    fi
}
trap hpc_service_cleanup EXIT HUP INT TERM

hpc_service_ensure_dir "${STATE_DIR}"
hpc_service_ensure_dir "${HOST_KEYS_DIR}"
[[ -f "${AUTHORIZED_KEYS_FILE}" ]] || hpc_service_die "authorized keys file not found: ${AUTHORIZED_KEYS_FILE}"

AUTH_KEYS_DIR="${STATE_DIR}/authorized-keys"
hpc_service_ensure_dir "${AUTH_KEYS_DIR}"
chmod 700 "${AUTH_KEYS_DIR}" || true
cp "${AUTHORIZED_KEYS_FILE}" "${AUTH_KEYS_DIR}/authorized_keys"
chmod 600 "${AUTH_KEYS_DIR}/authorized_keys" || true

if [[ ! -f "${HOST_KEYS_DIR}/dropbear_ed25519_host_key" ]]
then
    dropbearkey -t ed25519 -f "${HOST_KEYS_DIR}/dropbear_ed25519_host_key" >/dev/null 2>&1
fi

dropbear \
    -F \
    -E \
    -e \
    -m \
    -s \
    -w \
    -P "${STATE_DIR}/sshd.pid" \
    -p "${BIND_ADDRESS}:${PORT}" \
    -r "${HOST_KEYS_DIR}/dropbear_ed25519_host_key" \
    -D "${AUTH_KEYS_DIR}" &
CHILD_PID=$!

hpc_service_wait_for_port 127.0.0.1 "${PORT}" 30 || hpc_service_die "sshd did not become ready on port ${PORT}"

hpc_service_write_env_file "${METADATA_FILE}" \
    "SERVICE=sshd" \
    "HOST=$(hpc_service_hostname)" \
    "PORT=${PORT}" \
    "BIND_ADDRESS=${BIND_ADDRESS}" \
    "STATUS=ready"

wait "${CHILD_PID}"
