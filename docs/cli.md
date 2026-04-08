# hpc-dev CLI

This document describes the current behavior on `codex/codex-vscode-remote`, which builds on the supported fallback baseline from `codex/pre-rstudio-recovery`.

There are two supported tracks on this branch:

- VS Code Remote compatibility track: legacy helper mode, legacy workbench image first, `--home-mode real`, `--access both`, `--service jupyter`
- clean browser/editor track: explicit helper mode, isolated dev-home by default, owned image, `jupyter` or `code-server`

Primary entrypoint:

```bash
bash bin/hpc-dev plan  --mode local|slurm --image IMAGE --workspace PATH [options]
bash bin/hpc-dev start --mode local|slurm --image IMAGE --workspace PATH [options]
bash bin/hpc-dev status --last
bash bin/hpc-dev stop   --last
bash bin/hpc-dev cleanup --dry-run
bash bin/hpc-dev ssh    --last
bash bin/hpc-dev ssh-config --last
bash bin/hpc-dev tunnel --last
```

Recommended config location:

```text
~/.config/hpc-dev/config.env
```

For testing, you can point the wrapper at an alternate config with:

```bash
HPC_DEV_CONFIG_FILE=/path/to/config.env bash bin/hpc-dev plan ...
```

Useful override env vars for testing or staging:

```bash
HPC_DEV_STATE_ROOT
HPC_DEV_DEV_HOME_ROOT
HPC_DEV_CACHE_DIR
HPC_DEV_ENGINE_TMP_DIR
HPC_DEV_CONTAINER_TMP_ROOT
```

The new wrappers separate:

- persistent dev home
- real home
- workspace
- session state
- engine cache
- engine tmp
- container `/tmp`

Example:

```bash
bash bin/hpc-dev plan \
  --mode slurm \
  --image /path/to/image.sif \
  --workspace /path/to/project \
  --access ssh \
  --group kalebic \
  --group testa
```

For SLURM jobs, prefer storing SIF images in shared storage instead of inside the repo checkout. A typical pattern is:

```text
/group/kalebic/Oliviero/envs/hpc-dev.sif
```

Access modes:

- `--access ssh`: start `sshd`, optionally add browser services
- `--access browser`: browser-facing services only; requires `--helper-mode explicit`
- `--access both`: `sshd` plus browser-facing services; works with `--helper-mode legacy` for `jupyter`, and with `--helper-mode explicit` for `jupyter` or `code-server`

If `--access` is omitted, `ssh` is the default.

Current recommendation:

- local/VM: `ssh`, `browser`, or `both` all remain useful
- SLURM/HPC for VS Code Remote: prefer `--helper-mode legacy --access both --service jupyter --home-mode real` with the legacy workbench image first
- SLURM/HPC for owned-image browser/editor work: prefer `--helper-mode explicit --access both`
- SLURM `--access browser` is temporarily disabled because browser services bind to loopback inside the compute node and direct login-host forwarding is not reliable yet
- `RStudio` is currently disabled in the wrapper; use Jupyter or code-server for now
- Python and minimal R-in-VSCode work are the intended editor targets on this branch

Examples:

```bash
# VS Code Remote compatibility path: legacy workbench image first
bash bin/hpc-dev start \
  --mode slurm \
  --image /group/kalebic/Oliviero/envs/workbench-base-1.7.0.sif \
  --workspace /path/to/project \
  --home-mode real \
  --access both \
  --service jupyter \
  --helper-mode legacy \
  --group kalebic

# Clean owned-image path: Jupyter through the tunneled session
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --access both \
  --service jupyter \
  --helper-mode explicit \
  --group kalebic

# Local or VM browser-only Jupyter session
bash bin/hpc-dev start \
  --mode local \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --access browser \
  --service jupyter \
  --helper-mode explicit \
  --group kalebic

# code-server through the same tunneled session
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --access both \
  --service codeserver \
  --helper-mode explicit \
  --group kalebic
```

Gradual cutover to the owned image helper contract:

```bash
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --access both \
  --service jupyter \
  --helper-mode explicit \
  --group kalebic
```

Recommended rollout:

- keep `HELPER_MODE=legacy` as the default until the owned image passes the smoke test
- use `--helper-mode legacy --access both --service jupyter --home-mode real` for the VS Code Remote compatibility track
- use `--home-mode project` only as a fallback compatibility diagnostic if real-home VS Code behavior still fails; that fallback may reintroduce project-local `.ssh` material for legacy SSH auth
- use `--helper-mode explicit` only with the owned image path
- use `--access browser` and `--service codeserver` only on the explicit helper path
- prefer `--access both` on SLURM so browser services tunnel through container `sshd`
- use Jupyter and code-server as the supported browser-facing services on this branch

Session lifecycle behavior:

- `--last` always means the exact recorded last session
- `status` reports whether that session is `running`, `pending`, `stopped`, or `gone`
- `stop` is idempotent and reports `already stopped` if the SLURM job or local service is already gone
- `ssh`, `tunnel`, and `ssh-config` require a live running session and fail clearly on stale sessions

Session cleanup:

```bash
bash bin/hpc-dev cleanup --dry-run
bash bin/hpc-dev cleanup
bash bin/hpc-dev cleanup --all-stopped
bash bin/hpc-dev cleanup --last
```

Cleanup removes only per-session state and per-session container tmp directories. It never removes images, caches, the persistent dev home, or project files.

Filesystem layout inside the container:

- project workspace: `/workspace`
- persistent dev home: the default login directory on the explicit owned-image track
- real host home: the login directory on the VS Code compatibility track when `--home-mode real` is used
- mounted real home path: `/host-home`
- group/shared storage: its real mounted path, for example `/group/kalebic`

VS Code Remote-SSH workflow:

1. Start a SLURM session with the compatibility track first:

```bash
bash bin/hpc-dev start \
  --mode slurm \
  --image /group/kalebic/Oliviero/envs/workbench-base-1.7.0.sif \
  --workspace /path/to/project \
  --home-mode real \
  --access both \
  --service jupyter \
  --helper-mode legacy \
  --group kalebic
```
2. Print SSH config blocks with:

```bash
bash bin/hpc-dev ssh-config --last
```

3. Paste the printed block into `~/.ssh/config` on your Mac.
4. Connect from local VS Code using Remote-SSH.
5. Once connected, open `/workspace` explicitly. On the compatibility track, the remote window should land in the real home; on the explicit owned-image track, it lands in the persistent dev home.
6. On the compatibility track, `HOME` should come from `--home-mode real`, which helps VS Code discover the user’s existing conda and Jupyter state.
7. Treat this as a browsing/open-folder workflow. Do not rely on in-container PTY-backed terminals on this branch.

SSH note:

- `ssh` and `ssh-config` remain useful for tunneling and session inspection
- plain interactive in-container SSH/PTTY is not a supported workflow on this cluster right now
- use browser-facing workflows (`both + jupyter`, `both + code-server`) as the supported path today
- for VS Code Remote, start with the legacy compatibility track before trying the owned-image explicit path

Editor note:

- `code-server` works and is isolated from Posit Workbench state.
- GitHub/Copilot chat-style extensions inside `code-server` should be treated as best-effort, not the primary supported editor workflow.
- local VS Code Remote-SSH can still be useful for browsing and opening `/workspace`, and the Codex IDE extension is the intended validation target on this branch.
- treat Codex here as an open-folder/editing workflow and do not rely on in-container PTY-backed terminals.
- use [tests/manual/phase3-codex-vscode.md](/Users/oliviero.leonardi/Documents/GitHub/hpc_containers_scripts/tests/manual/phase3-codex-vscode.md) for the end-to-end checklist.
