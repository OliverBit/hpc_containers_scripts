#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CMD=(bash "${ROOT_DIR}/bin/hpc-dev" start --mode slurm)

while [[ $# -gt 0 ]]
do
    case "$1" in
        -i) IMAGE_NAME="${2:-}"; shift 2 ;;
        -t) IMAGE_TAG="${2:-}"; shift 2 ;;
        -H) CMD+=(--workspace "${2:-}"); shift 2 ;;
        -B) CMD+=(--bind "${2:-}"); shift 2 ;;
        --access) CMD+=(--access "${2:-}"); shift 2 ;;
        --jupyter) CMD+=(--service jupyter); shift ;;
        --rstudio) CMD+=(--service rstudio); shift ;;
        --codeserver) CMD+=(--service codeserver); shift ;;
        -N) CMD+=(--session-name "${2:-}"); shift 2 ;;
        -n) CMD+=(--cpus "${2:-}"); shift 2 ;;
        -m) CMD+=(--mem "${2:-}"); shift 2 ;;
        --time) CMD+=(--time "${2:-}"); shift 2 ;;
        --email) CMD+=(--email "${2:-}"); shift 2 ;;
        --codeserver-port) CMD+=(--codeserver-port "${2:-}"); shift 2 ;;
        --engine|--singularity-path) CMD+=(--engine "${2:-}"); shift 2 ;;
        --helper-mode) CMD+=(--helper-mode "${2:-}"); shift 2 ;;
        --singularity-cache|--cache-dir) CMD+=(--cache-dir "${2:-}"); shift 2 ;;
        --tmp) CMD+=(--container-tmp-root "${2:-}"); shift 2 ;;
        -h|--help)
            echo "Compatibility shim for the old SLURM wrapper."
            echo "Use 'hpc-dev start --mode slurm ...' for the new interface."
            exec bash "${ROOT_DIR}/bin/hpc-dev" --help
            ;;
        *)
            CMD+=("$1")
            shift
            ;;
    esac
done

if [[ -n "${IMAGE_NAME:-}" && -n "${IMAGE_TAG:-}" ]]
then
    CMD+=(--image "docker://${IMAGE_NAME}:${IMAGE_TAG}")
fi

echo "Warning: slurm_docker_run.sh is deprecated; use 'hpc-dev start --mode slurm ...' instead." >&2
exec "${CMD[@]}"
