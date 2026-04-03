# Owned Image Path

The repository now contains starter scaffolds for the owned-image path:

- `container/Dockerfile`
- `container/apptainer.def`
- `container/build-apptainer.sh`
- `container/smoke-test-image.sh`
- `container/helpers/hpc-service-*.sh`

What is implemented in the repo now:

- explicit helper argument contracts
- readiness checks
- per-service metadata files
- explicit ssh authorized-keys path
- rootless-friendly SSH service through `hpc-service-sshd.sh` using Dropbear, including PTY checks
- pinned R + RStudio Server install on Ubuntu 24.04
- Jupyter workspace-root support
- loopback binding for Jupyter, RStudio, and code-server
- access-mode aware wrapper integration for `ssh`, `browser`, and `both`
- isolated code-server config/data/cache paths under the dedicated dev-home namespace
- RStudio helper config that keeps runtime and project-user data under session state

What still needs site-specific work before production use:

- any institute-specific certificates, modules, or package mirrors
- Codex installation in the image
- final production validation of code-server and RStudio on the cluster

The intended Phase 2 direction is:

1. build an owned image from the scaffold
2. verify `hpc-service-sshd.sh --help`, `hpc-service-jupyter.sh --help`, `hpc-service-rstudio.sh --help`, and `hpc-service-codeserver.sh --help` inside the image
3. verify SSH/editor and combined access modes with the owned image

Suggested commands:

```bash
bash container/build-apptainer.sh /path/to/hpc-dev.sif
bash container/smoke-test-image.sh --image /path/to/hpc-dev.sif
```

If interactive SSH/PTTY is the blocker, run the control comparison harness on a compute node before changing SSH servers again:

```bash
apptainer build /group/kalebic/Oliviero/envs/control-workbench-base-1.7.0.sif \
  docker://nfdata/workbench:base-1.7.0

bash container/compare-ssh-control.sh \
  --current-image /path/to/hpc-dev.sif \
  --control-sif /group/kalebic/Oliviero/envs/control-workbench-base-1.7.0.sif \
  --report-root /group/kalebic/Oliviero/hpc-dev-ssh-control/latest
```

See `docs/ssh-pty-recovery.md` for the decision tree and the sanctioned fallback target.

For SLURM, prefer storing the final SIF in shared storage rather than in the repository tree. A typical path is:

```text
/group/kalebic/Oliviero/envs/hpc-dev.sif
```

Once the smoke test passes, exercise the wrapper cutover with:

```bash
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --access both \
  --service rstudio \
  --helper-mode explicit \
  --group kalebic
```

Recommended next smoke on the cluster:

```bash
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --access both \
  --service codeserver \
  --helper-mode explicit \
  --group kalebic
```

Recommended acceptance sequence on the cluster:

1. `both + jupyter`
2. `both + code-server`
3. `both + rstudio`
4. plain terminal SSH with `ssh hpc-dev-current`
5. VS Code Remote-SSH plus `/workspace`

Current support guidance:

- local/VM: browser-only mode remains useful
- SLURM: prefer `--access both`
- SLURM browser-only mode is intentionally disabled for now until a safe forwarding design replaces the old direct-login-host assumption

Filesystem layout for the remote-editor workflow:

- login lands in the persistent dev home
- open your project at `/workspace`
- real home remains available at `/host-home`
- group paths remain available at their real mount points, for example `/group/kalebic`
- RStudio project-user data is redirected into session state so the project tree stays clean

For Docker builds from the repository root:

```bash
docker build -f container/Dockerfile -t hpc-dev:latest .
```
