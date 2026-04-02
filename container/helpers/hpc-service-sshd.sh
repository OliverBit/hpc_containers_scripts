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
LOGIN_HOME=""
LOGIN_AUTH_DIR=""
LOGIN_AUTH_FILE=""
LOGIN_AUTH_BACKUP=""

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
    if [[ -n "${LOGIN_AUTH_BACKUP}" && -f "${LOGIN_AUTH_BACKUP}" ]]
    then
        mv "${LOGIN_AUTH_BACKUP}" "${LOGIN_AUTH_FILE}" 2>/dev/null || true
    elif [[ -n "${LOGIN_AUTH_FILE}" && -f "${LOGIN_AUTH_FILE}" && "${AUTHORIZED_KEYS_FILE}" != "${LOGIN_AUTH_FILE}" ]]
    then
        rm -f "${LOGIN_AUTH_FILE}" 2>/dev/null || true
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

LOGIN_HOME="${HOME:-$(getent passwd "$(id -un)" 2>/dev/null | awk -F: '{print $6}')}"
[[ -n "${LOGIN_HOME}" ]] || hpc_service_die "unable to determine login home for ssh service"
LOGIN_AUTH_DIR="${LOGIN_HOME}/.ssh"
LOGIN_AUTH_FILE="${LOGIN_AUTH_DIR}/authorized_keys"
hpc_service_ensure_dir "${LOGIN_AUTH_DIR}"
chmod 700 "${LOGIN_AUTH_DIR}" || true

if [[ "${AUTHORIZED_KEYS_FILE}" != "${LOGIN_AUTH_FILE}" ]]
then
    if [[ -f "${LOGIN_AUTH_FILE}" ]]
    then
        LOGIN_AUTH_BACKUP="${STATE_DIR}/authorized_keys.backup"
        cp "${LOGIN_AUTH_FILE}" "${LOGIN_AUTH_BACKUP}"
    fi
    cp "${AUTHORIZED_KEYS_FILE}" "${LOGIN_AUTH_FILE}"
fi
chmod 600 "${LOGIN_AUTH_FILE}" || true

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
    -r "${HOST_KEYS_DIR}/dropbear_ed25519_host_key" &
CHILD_PID=$!

hpc_service_wait_for_port 127.0.0.1 "${PORT}" 30 || hpc_service_die "sshd did not become ready on port ${PORT}"

hpc_service_write_env_file "${METADATA_FILE}" \
    "SERVICE=sshd" \
    "HOST=$(hpc_service_hostname)" \
    "PORT=${PORT}" \
    "BIND_ADDRESS=${BIND_ADDRESS}" \
    "STATUS=ready"

wait "${CHILD_PID}"
