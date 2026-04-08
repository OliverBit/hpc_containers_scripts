# Phase 3 Codex-on-VSCode Checklist

Goal: validate the extension-first editor workflow on `codex/codex-vscode-remote` without relying on interactive in-container SSH/PTTY.

This checklist starts with the legacy compatibility track, not the owned-image explicit-helper track.

1. Start with the legacy compatibility image on the HPC:

```bash
bash bin/hpc-dev start \
  --mode slurm \
  --image /group/kalebic/Oliviero/envs/workbench-base-1.7.0.sif \
  --workspace /group/kalebic/Oliviero/projects/NF1 \
  --home-mode real \
  --access both \
  --service jupyter \
  --helper-mode legacy \
  --group kalebic \
  --cpus 4 \
  --mem 16G
```

Expected startup signals:

- `sshd` registers
- `jupyter` registers
- `ssh-config --last` prints a usable SSH block

2. Print the SSH config block and use it from the Mac:

```bash
bash bin/hpc-dev ssh-config --last
```

3. In local VS Code on the Mac:

- install/sign in to the Codex IDE extension locally
- connect with Remote-SSH using the printed config
- open `/workspace`
- confirm the connection stays stable for at least 10 minutes after the Python, R, and Jupyter extensions load

4. Validate the Python workflow:

- ask Codex to inspect repository files
- ask Codex to make a small edit in a Python file
- verify the diff appears in `/workspace`
- check whether your existing conda environments become visible now that `HOME` is backed by the real home
- verify a simple non-interactive command works, for example:

```bash
python -c "print('ok')"
```

5. Validate the R workflow:

- ask Codex to inspect `.R` files
- ask Codex to make a small edit in an R file
- verify the diff appears in `/workspace`
- verify a simple non-interactive R command works:

```bash
Rscript -e 'sessionInfo()'
```

- confirm no unexpected R runtime or package state is written into the project tree

6. If the real-home compatibility path still fails, retry the same workflow with `--home-mode project` as a fallback-only diagnostic.
   Treat this as a temporary compatibility escape hatch: it may reintroduce project-local `.ssh` material for legacy SSH auth.

7. Regression checks:

- `both + jupyter` with the legacy compatibility path still works
- `both + code-server` with the explicit owned-image path still works
- `bash bin/hpc-dev status --last` reports the session cleanly
- `bash bin/hpc-dev stop --last` is idempotent
- `bash bin/hpc-dev cleanup --dry-run` only targets stale state by default

8. Owned-image explicit path remains a secondary track on this branch. Only after the legacy compatibility path is stable should you validate the owned image for Codex-on-VSCode.

9. Non-goals for this phase:

- do not require plain interactive `ssh hpc-dev-current`
- do not require PTY-backed terminal success
- do not require `RStudio`
- do not require remote Codex CLI
