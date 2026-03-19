#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DEF_FILE="${ROOT_DIR}/container/apptainer.def"
ENGINE="${ENGINE:-auto}"
OUTPUT_IMAGE="${ROOT_DIR}/container/hpc-dev.sif"

usage() {
    cat <<'EOF'
Usage:
  container/build-apptainer.sh [--engine apptainer|singularity] [OUTPUT_IMAGE]
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

while [[ $# -gt 0 ]]
do
    case "$1" in
        --engine) ENGINE="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *)
            OUTPUT_IMAGE="$1"
            shift
            ;;
    esac
done

ENGINE_CMD="$(resolve_engine)"

echo "Building ${OUTPUT_IMAGE} with ${ENGINE_CMD} from ${DEF_FILE}"
"${ENGINE_CMD}" build "${OUTPUT_IMAGE}" "${DEF_FILE}"
