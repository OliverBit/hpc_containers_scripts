# hpc-dev

This branch, `codex/codex-vscode-remote`, builds on the recovery baseline from `codex/pre-rstudio-recovery` and is the current extension-first validation line for Codex in local VS Code against the remote HPC container.

What is supported here:

- SLURM `--access both` sessions
- Jupyter through the tunneled session
- code-server through the tunneled session
- minimal R runtime in the owned image for VS Code work
- stale-session handling with `status`, `stop`, and `cleanup`
- tunnel and SSH-config output for session inspection and browser forwarding

Current limitations:

- `RStudio` is disabled in the wrapper
- plain interactive in-container SSH/PTTY is not supported on this cluster
- SLURM `--access browser` is disabled

Recommended HPC path:

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

You can swap `--service jupyter` for `--service codeserver` when you want the browser editor path instead.

Where to go next:

- CLI usage and supported behavior: [docs/cli.md](/Users/oliviero.leonardi/Documents/GitHub/hpc_containers_scripts/docs/cli.md)
- Owned-image notes and smoke guidance: [docs/image-build.md](/Users/oliviero.leonardi/Documents/GitHub/hpc_containers_scripts/docs/image-build.md)
- Manual validation checklists: [tests/manual/](/Users/oliviero.leonardi/Documents/GitHub/hpc_containers_scripts/tests/manual)
- Codex-on-VSCode validation sequence: [tests/manual/phase3-codex-vscode.md](/Users/oliviero.leonardi/Documents/GitHub/hpc_containers_scripts/tests/manual/phase3-codex-vscode.md)

Historical architecture and migration notes are still kept in `docs/`, but they are reference material only and may describe older RStudio or PTY-SSH assumptions that are not part of the supported workflow on this branch.
