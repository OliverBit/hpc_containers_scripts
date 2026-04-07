# Migration Notes

Historical reference only.
This document describes the legacy path and migration context. It may mention RStudio and older runtime assumptions that are not part of the current supported workflow.
For the supported fallback workflow on `codex/pre-rstudio-recovery`, see `README.md`, `docs/cli.md`, and `docs/image-build.md`.

Current legacy scripts remain in the repository root as frozen references.

The new workflow lives under:

- `bin/hpc-dev`
- `lib/hpc-dev/`

Compatibility shims:

- `bin/slurm_docker_run.sh`
- `bin/local_docker_run.sh`

Behavioral changes in Phase 1:

- project directory is no longer used as container home by default
- `.ssh`, `.sshd-*`, `.rserver-*`, and service discovery move out of the project
- cache defaults are intended to stay off home
- service discovery is session-specific
