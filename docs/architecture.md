# Phase 1 Architecture

Historical reference only.
This document describes the legacy path and migration context. It may mention RStudio and older runtime assumptions that are not part of the current supported workflow.
For the current workflow on `codex/codex-vscode-remote`, which builds on the `codex/pre-rstudio-recovery` baseline, see `README.md`, `docs/cli.md`, and `docs/image-build.md`.

Phase 1 keeps the current container-side helper contract but moves host-side runtime state out of the project directory.

Key paths:

- workspace mount: `/workspace`
- real home bind: `/host-home`
- dev home bind: `/dev-home`
- default container home source: persistent dev home
- session state: `~/.local/state/hpc-dev/sessions/<session-id>`
- persistent cache: configurable, intended to live off home
- engine tmp: configurable, intended to live on scratch
- container `/tmp`: per-session host path

Phase 1 still launches legacy helper names:

- `run_sshd.sh`
- `run_jupyterlab.sh`
- `run_rstudioserver.sh`

The wrappers set per-session `DAT_FILE`, `SSH_CONFIG_PATH`, and `COOKIE_FILE` so service discovery and runtime state are session-scoped rather than project-scoped.
