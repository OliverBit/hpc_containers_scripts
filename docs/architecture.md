# Phase 1 Architecture

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
