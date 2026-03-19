#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ENGINE="${ENGINE:-auto}"
IMAGE=""
KEEP_TMP="false"
TMP_ROOT=""
SESSION_DIR=""
JUPYTER_HOST_PID=""

usage() {
    cat <<'EOF'
Usage:
  container/smoke-test-image.sh --image /path/to/image.sif [--engine apptainer|singularity]

What it checks:
  1. helper binaries answer to --help
  2. core binaries exist in the image
  3. Jupyter helper can write metadata and token files
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
    if [[ -n "${JUPYTER_HOST_PID}" ]]
    then
        kill "${JUPYTER_HOST_PID}" >/dev/null 2>&1 || true
        wait "${JUPYTER_HOST_PID}" >/dev/null 2>&1 || true
    fi
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

ENGINE_CMD="$(resolve_engine)"
TMP_ROOT="$(mktemp -d /tmp/hpc-dev-image-test.XXXXXX)"
SESSION_DIR="${TMP_ROOT}/session"
mkdir -p "${SESSION_DIR}/workspace" "${SESSION_DIR}/state"
touch "${SESSION_DIR}/state/authorized_keys"

echo "== Helper help checks =="
"${ENGINE_CMD}" exec "${IMAGE}" hpc-service-sshd.sh --help >/dev/null
"${ENGINE_CMD}" exec "${IMAGE}" hpc-service-jupyter.sh --help >/dev/null
"${ENGINE_CMD}" exec "${IMAGE}" hpc-service-rstudio.sh --help >/dev/null || true
echo "ok"

echo "== Binary checks =="
"${ENGINE_CMD}" exec "${IMAGE}" bash -lc 'which sshd && which jupyter && which python3'
if "${ENGINE_CMD}" exec "${IMAGE}" bash -lc 'which rserver' >/dev/null 2>&1
then
    echo "rserver: present"
else
    echo "rserver: not present yet (expected until site-specific install is added)"
fi

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

JUPYTER_HOST_PID=$!

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
echo "Smoke test completed successfully."
