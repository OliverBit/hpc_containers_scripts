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
    if [[ -n "${CHILD_PID}" ]]
    then
        kill "${CHILD_PID}" >/dev/null 2>&1 || true
    fi
}
trap hpc_service_cleanup EXIT HUP INT TERM

hpc_service_ensure_dir "${STATE_DIR}"
hpc_service_ensure_dir "${HOST_KEYS_DIR}"
[[ -f "${AUTHORIZED_KEYS_FILE}" ]] || hpc_service_die "authorized keys file not found: ${AUTHORIZED_KEYS_FILE}"

if [[ ! -f "${HOST_KEYS_DIR}/ssh_host_rsa_key" ]]
then
    ssh-keygen -q -t rsa -b 4096 -N '' -f "${HOST_KEYS_DIR}/ssh_host_rsa_key" >/dev/null
fi
if [[ ! -f "${HOST_KEYS_DIR}/ssh_host_ecdsa_key" ]]
then
    ssh-keygen -q -t ecdsa -N '' -f "${HOST_KEYS_DIR}/ssh_host_ecdsa_key" >/dev/null
fi
if [[ ! -f "${HOST_KEYS_DIR}/ssh_host_ed25519_key" ]]
then
    ssh-keygen -q -t ed25519 -N '' -f "${HOST_KEYS_DIR}/ssh_host_ed25519_key" >/dev/null
fi

SSHD_CONFIG="${STATE_DIR}/sshd_config"
cat > "${SSHD_CONFIG}" <<EOF
HostKey ${HOST_KEYS_DIR}/ssh_host_rsa_key
HostKey ${HOST_KEYS_DIR}/ssh_host_ecdsa_key
HostKey ${HOST_KEYS_DIR}/ssh_host_ed25519_key
AuthorizedKeysFile ${AUTHORIZED_KEYS_FILE}
PidFile ${STATE_DIR}/sshd.pid
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
UseDNS no
X11Forwarding yes
AllowAgentForwarding yes
AllowTcpForwarding yes
AllowStreamLocalForwarding yes
PermitTTY yes
PrintMotd no
PrintLastLog no
ClientAliveInterval 30
ClientAliveCountMax 6
LogLevel VERBOSE
AcceptEnv LANG LC_* TERM
Subsystem sftp internal-sftp
EOF

/usr/sbin/sshd -D -e -p "${PORT}" -o "ListenAddress=${BIND_ADDRESS}" -f "${SSHD_CONFIG}" &
CHILD_PID=$!

hpc_service_wait_for_port 127.0.0.1 "${PORT}" 30 || hpc_service_die "sshd did not become ready on port ${PORT}"

hpc_service_write_env_file "${METADATA_FILE}" \
    "SERVICE=sshd" \
    "HOST=$(hpc_service_hostname)" \
    "PORT=${PORT}" \
    "BIND_ADDRESS=${BIND_ADDRESS}" \
    "STATUS=ready"

wait "${CHILD_PID}"
