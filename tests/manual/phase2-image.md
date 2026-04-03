# Phase 2 Owned Image Checklist

1. Build the image:

```bash
bash container/build-apptainer.sh /path/to/hpc-dev.sif
```

2. Run the smoke test:

```bash
bash container/smoke-test-image.sh --image /path/to/hpc-dev.sif
```

3. Confirm the smoke test reports:

- helper help checks pass
- `dropbear`, `sshd`, `jupyter`, `python3`, `code-server`, and `rserver` exist
- `sshd` helper accepts a remote `ssh -T` command
- `sshd` helper accepts a PTY-backed `ssh -tt` command
- RStudio metadata is created and reports auth-none mode
- Jupyter metadata is created
- code-server metadata and password are created

4. After the image smoke test passes, validate wrapper integration:

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

5. Validate browser-only access:

```bash
bash bin/hpc-dev start \
  --mode local \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --access browser \
  --service codeserver \
  --helper-mode explicit \
  --group kalebic
```

6. On SLURM, treat `--access both` as the supported HPC mode and verify:

- `bash bin/hpc-dev ssh-config --last` prints ready-to-paste SSH config blocks
- plain `ssh hpc-dev-current` opens a shell
- local VS Code Remote-SSH can connect with that config
- the project is opened at `/workspace`
- `bash bin/hpc-dev cleanup --dry-run` reports only stale sessions by default

7. If plain `ssh` or the VS Code integrated terminal still fail, do not keep changing SSH servers blindly. Run:

```bash
apptainer build /group/kalebic/Oliviero/envs/control-workbench-base-1.7.0.sif \
  docker://nfdata/workbench:base-1.7.0

bash container/compare-ssh-control.sh \
  --current-image /path/to/hpc-dev.sif \
  --control-sif /group/kalebic/Oliviero/envs/control-workbench-base-1.7.0.sif \
  --report-root /group/kalebic/Oliviero/hpc-dev-ssh-control/latest
```

Then classify the result using `docs/ssh-pty-recovery.md` before deciding whether to attempt one final SSH fix or fall back to `5788d53`.
