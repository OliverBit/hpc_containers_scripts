# Phase 3 Codex-on-VSCode Checklist

Goal: validate the extension-first editor workflow on `codex/codex-vscode-remote` without relying on interactive in-container SSH/PTTY.

1. Build and publish the owned image from this branch on the Mac:

```bash
docker buildx build \
  --platform linux/amd64 \
  -f container/Dockerfile \
  -t ghcr.io/oliverbit/hpc-dev:codex-vscode-remote \
  --push .
```

2. Rebuild the SIF on the HPC:

```bash
module load apptainer
apptainer build --force /group/kalebic/Oliviero/envs/hpc-dev-codex-vscode-remote.sif \
  docker://ghcr.io/oliverbit/hpc-dev:codex-vscode-remote
```

3. Confirm the image smoke test passes:

```bash
bash container/smoke-test-image.sh --image /group/kalebic/Oliviero/envs/hpc-dev-codex-vscode-remote.sif
```

Expected smoke signals:

- `sshd`, `jupyter`, `python3`, `code-server`, `R`, and `Rscript` exist
- non-interactive SSH smoke passes
- R runtime smoke passes
- Jupyter metadata is created
- code-server metadata and password files are created

4. Start a supported SLURM session:

```bash
bash bin/hpc-dev start \
  --mode slurm \
  --image /group/kalebic/Oliviero/envs/hpc-dev-codex-vscode-remote.sif \
  --workspace /path/to/project \
  --access both \
  --service jupyter \
  --helper-mode explicit \
  --group kalebic
```

5. Print the SSH config block and use it from the Mac:

```bash
bash bin/hpc-dev ssh-config --last
```

6. In local VS Code on the Mac:

- install/sign in to the Codex IDE extension locally
- connect with Remote-SSH using the printed config
- open `/workspace`

7. Validate the Python workflow:

- ask Codex to inspect repository files
- ask Codex to make a small edit in a Python file
- verify the diff appears in `/workspace`
- verify a simple non-interactive command works, for example:

```bash
python -c "print('ok')"
```

8. Validate the R workflow:

- ask Codex to inspect `.R` files
- ask Codex to make a small edit in an R file
- verify the diff appears in `/workspace`
- verify a simple non-interactive R command works:

```bash
Rscript -e 'sessionInfo()'
```

- confirm no unexpected R runtime or package state is written into the project tree

9. Regression checks:

- `both + jupyter` still works
- `both + code-server` still works
- `bash bin/hpc-dev status --last` reports the session cleanly
- `bash bin/hpc-dev stop --last` is idempotent
- `bash bin/hpc-dev cleanup --dry-run` only targets stale state by default

10. Non-goals for this phase:

- do not require plain interactive `ssh hpc-dev-current`
- do not require PTY-backed terminal success
- do not require `RStudio`
- do not require remote Codex CLI
