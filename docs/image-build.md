# Owned Image Path

The repository now contains starter scaffolds for the owned-image path:

- `container/Dockerfile`
- `container/apptainer.def`
- `container/build-apptainer.sh`
- `container/smoke-test-image.sh`
- `container/helpers/hpc-service-*.sh`

What is production-ready now:

- explicit helper argument contracts
- readiness checks
- per-service metadata files
- explicit ssh authorized-keys path
- Jupyter workspace-root support
- loopback binding for Jupyter and RStudio

What still needs site-specific work before production use:

- R and RStudio Server installation
- any institute-specific certificates, modules, or package mirrors
- Codex installation in the image
- final wrapper cutover from legacy helper names to `hpc-service-*`

The intended Phase 2 direction is:

1. build an owned image from the scaffold
2. verify `hpc-service-sshd.sh --help`, `hpc-service-jupyter.sh --help`, and `hpc-service-rstudio.sh --help` inside the image
3. switch wrappers from `run_*` helper names to explicit `exec` of `hpc-service-*`

Suggested commands:

```bash
bash container/build-apptainer.sh /path/to/hpc-dev.sif
bash container/smoke-test-image.sh --image /path/to/hpc-dev.sif
```

Once the smoke test passes, exercise the wrapper cutover with:

```bash
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --service sshd \
  --service jupyter \
  --helper-mode explicit \
  --group kalebic
```

For Docker builds from the repository root:

```bash
docker build -f container/Dockerfile -t hpc-dev:latest .
```
