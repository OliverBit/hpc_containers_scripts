#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ENGINE="${ENGINE:-auto}"
IMAGE=""
KEEP_TMP="false"
TMP_ROOT=""
SESSION_DIR=""
HELPER_PIDS=()

usage() {
    cat <<'EOF'
Usage:
  container/smoke-test-image.sh --image /path/to/image.sif [--engine apptainer|singularity]

What it checks:
  1. helper binaries answer to --help
  2. core binaries exist in the image
  3. sshd helper can write metadata and accept an SSH command
  4. Jupyter helper can write metadata and token files
  5. code-server helper can write metadata and password files
EOF
}

resolve_engine() {
    if [[ "${ENGINE}" != "auto" ]]
    then
        command -v "${ENGINE}" >/dev/null 2>&1 || {
            echo "Error: requested engine '${ENGINE}' not found" >&2
            exit 1
        }
        printf '%s\n' "${ENGINE}"
        return 0
    fi

    if command -v apptainer >/dev/null 2>&1
    then
        printf '%s\n' "apptainer"
    elif command -v singularity >/dev/null 2>&1
    then
        printf '%s\n' "singularity"
    else
        echo "Error: neither apptainer nor singularity is available" >&2
        exit 1
    fi
}

cleanup() {
    local pid
    for pid in "${HELPER_PIDS[@]-}"
    do
        [[ -n "${pid}" ]] || continue
        kill "${pid}" >/dev/null 2>&1 || true
        wait "${pid}" >/dev/null 2>&1 || true
    done
    if [[ "${KEEP_TMP}" != "true" && -n "${TMP_ROOT}" && -d "${TMP_ROOT}" ]]
    then
        rm -rf "${TMP_ROOT}"
    fi
}
trap cleanup EXIT HUP INT TERM

while [[ $# -gt 0 ]]
do
    case "$1" in
        --image) IMAGE="${2:-}"; shift 2 ;;
        --engine) ENGINE="${2:-}"; shift 2 ;;
        --keep-tmp) KEEP_TMP="true"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Error: unknown option $1" >&2; usage; exit 1 ;;
    esac
done

[[ -n "${IMAGE}" ]] || { usage; exit 1; }
[[ -f "${IMAGE}" ]] || { echo "Error: image not found: ${IMAGE}" >&2; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "Error: ssh client not found on host" >&2; exit 1; }
command -v ssh-keygen >/dev/null 2>&1 || { echo "Error: ssh-keygen not found on host" >&2; exit 1; }

ENGINE_CMD="$(resolve_engine)"
TMP_ROOT="$(mktemp -d /tmp/hpc-dev-image-test.XXXXXX)"
SESSION_DIR="${TMP_ROOT}/session"
mkdir -p "${SESSION_DIR}/workspace" "${SESSION_DIR}/state"
touch "${SESSION_DIR}/state/authorized_keys"

echo "== Helper help checks =="
"${ENGINE_CMD}" exec "${IMAGE}" hpc-service-sshd.sh --help >/dev/null
"${ENGINE_CMD}" exec "${IMAGE}" hpc-service-jupyter.sh --help >/dev/null
"${ENGINE_CMD}" exec "${IMAGE}" hpc-service-rstudio.sh --help >/dev/null || true
"${ENGINE_CMD}" exec "${IMAGE}" hpc-service-codeserver.sh --help >/dev/null
echo "ok"

echo "== Binary checks =="
"${ENGINE_CMD}" exec "${IMAGE}" bash -lc 'command -v sshd && command -v jupyter && command -v python3 && command -v code-server'
if "${ENGINE_CMD}" exec "${IMAGE}" bash -lc 'command -v rserver' >/dev/null 2>&1
then
    echo "rserver: present"
else
    echo "rserver: not present yet (expected until site-specific install is added)"
fi

echo "== sshd helper smoke test =="
SSH_TEST_PORT=38887
SSH_TEST_KEY="${SESSION_DIR}/state/ssh-smoke-key"
SSH_STATE_DIR="${SESSION_DIR}/state/sshd"

mkdir -p "${SSH_STATE_DIR}" "${SESSION_DIR}/state/hostkeys"
ssh-keygen -q -t ed25519 -N '' -f "${SSH_TEST_KEY}" >/dev/null
cat "${SSH_TEST_KEY}.pub" > "${SESSION_DIR}/state/authorized_keys"

"${ENGINE_CMD}" exec \
    -B "${SESSION_DIR}/state:/state" \
    "${IMAGE}" \
    hpc-service-sshd.sh \
    --port "${SSH_TEST_PORT}" \
    --state-dir /state/sshd \
    --metadata-file /state/sshd.env \
    --authorized-keys-file /state/authorized_keys \
    --host-keys-dir /state/hostkeys \
    --bind-address 127.0.0.1 > "${SESSION_DIR}/state/sshd.log" 2>&1 &

HELPER_PIDS+=("$!")

for _ in $(seq 1 30)
do
    if [[ -f "${SESSION_DIR}/state/sshd.env" ]]
    then
        break
    fi
    sleep 1
done

[[ -f "${SESSION_DIR}/state/sshd.env" ]] || {
    echo "Error: sshd metadata file was not created" >&2
    echo "Log follows:" >&2
    cat "${SESSION_DIR}/state/sshd.log" >&2 || true
    exit 1
}

grep -q '^SERVICE=sshd$' "${SESSION_DIR}/state/sshd.env" || {
    echo "Error: sshd metadata file is malformed" >&2
    cat "${SESSION_DIR}/state/sshd.env" >&2
    exit 1
}

for _ in $(seq 1 30)
do
    if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 "${SSH_TEST_PORT}" >/dev/null 2>&1
    then
        break
    fi
    sleep 1
done

if command -v nc >/dev/null 2>&1
then
    nc -z 127.0.0.1 "${SSH_TEST_PORT}" >/dev/null 2>&1 || {
        echo "Error: sshd port ${SSH_TEST_PORT} did not open" >&2
        cat "${SESSION_DIR}/state/sshd.log" >&2 || true
        exit 1
    }
fi

SSH_SMOKE_OUTPUT="$(ssh \
    -T \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i "${SSH_TEST_KEY}" \
    -p "${SSH_TEST_PORT}" \
    "$(id -un)@127.0.0.1" \
    'echo ssh-ok' 2>&1)" || {
    echo "Error: ssh remote command smoke test failed" >&2
    printf '%s\n' "${SSH_SMOKE_OUTPUT}" >&2
    cat "${SESSION_DIR}/state/sshd.log" >&2 || true
    exit 1
}

grep -q 'ssh-ok' <<< "${SSH_SMOKE_OUTPUT}" || {
    echo "Error: ssh smoke test did not return expected output" >&2
    printf '%s\n' "${SSH_SMOKE_OUTPUT}" >&2
    exit 1
}

echo "ok"

echo "== Jupyter helper smoke test =="
"${ENGINE_CMD}" exec \
    -B "${SESSION_DIR}/workspace:/workspace" \
    -B "${SESSION_DIR}/state:/state" \
    "${IMAGE}" \
    hpc-service-jupyter.sh \
    --port 38888 \
    --workspace /workspace \
    --state-dir /state \
    --metadata-file /state/jupyter.env > "${SESSION_DIR}/state/jupyter.log" 2>&1 &

HELPER_PIDS+=("$!")

for _ in $(seq 1 30)
do
    if [[ -f "${SESSION_DIR}/state/jupyter.env" ]]
    then
        break
    fi
    sleep 1
done

[[ -f "${SESSION_DIR}/state/jupyter.env" ]] || {
    echo "Error: jupyter metadata file was not created" >&2
    echo "Log follows:" >&2
    cat "${SESSION_DIR}/state/jupyter.log" >&2 || true
    exit 1
}

grep -q '^SERVICE=jupyter$' "${SESSION_DIR}/state/jupyter.env" || {
    echo "Error: jupyter metadata file is malformed" >&2
    cat "${SESSION_DIR}/state/jupyter.env" >&2
    exit 1
}

echo "ok"

echo "== code-server helper smoke test =="
"${ENGINE_CMD}" exec \
    -B "${SESSION_DIR}/workspace:/workspace" \
    -B "${SESSION_DIR}/state:/state" \
    "${IMAGE}" \
    hpc-service-codeserver.sh \
    --port 38889 \
    --workspace /workspace \
    --state-dir /state \
    --metadata-file /state/codeserver.env \
    --password-file /state/codeserver.password \
    --config-file /state/codeserver-config.yaml \
    --user-data-dir /state/code-server-data \
    --extensions-dir /state/code-server-data/extensions \
    --cache-home /state/code-server-cache > "${SESSION_DIR}/state/codeserver.log" 2>&1 &

HELPER_PIDS+=("$!")

for _ in $(seq 1 30)
do
    if [[ -f "${SESSION_DIR}/state/codeserver.env" ]]
    then
        break
    fi
    sleep 1
done

[[ -f "${SESSION_DIR}/state/codeserver.env" ]] || {
    echo "Error: code-server metadata file was not created" >&2
    echo "Log follows:" >&2
    cat "${SESSION_DIR}/state/codeserver.log" >&2 || true
    exit 1
}

grep -q '^SERVICE=codeserver$' "${SESSION_DIR}/state/codeserver.env" || {
    echo "Error: code-server metadata file is malformed" >&2
    cat "${SESSION_DIR}/state/codeserver.env" >&2
    exit 1
}

grep -q '^PASSWORD=' "${SESSION_DIR}/state/codeserver.env" || {
    echo "Error: code-server metadata is missing PASSWORD" >&2
    cat "${SESSION_DIR}/state/codeserver.env" >&2
    exit 1
}

[[ -f "${SESSION_DIR}/state/codeserver-config.yaml" ]] || {
    echo "Error: code-server config file was not created" >&2
    exit 1
}

[[ -d "${SESSION_DIR}/state/code-server-data/extensions" ]] || {
    echo "Error: code-server extensions directory was not created" >&2
    exit 1
}

[[ -d "${SESSION_DIR}/state/code-server-cache" ]] || {
    echo "Error: code-server cache home was not created" >&2
    exit 1
}

echo "ok"
echo "Smoke test completed successfully."
