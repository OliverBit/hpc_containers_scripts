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
- Jupyter workspace-root support
- loopback binding for Jupyter, RStudio, and code-server
- access-mode aware wrapper integration for `ssh`, `browser`, and `both`
- isolated code-server config/data/cache paths under the dedicated dev-home namespace

What still needs site-specific work before production use:

- R and RStudio Server installation
- any institute-specific certificates, modules, or package mirrors
- Codex installation in the image
- final production validation of code-server in the owned image

The intended Phase 2 direction is:

1. build an owned image from the scaffold
2. verify `hpc-service-sshd.sh --help`, `hpc-service-jupyter.sh --help`, `hpc-service-rstudio.sh --help`, and `hpc-service-codeserver.sh --help` inside the image
3. verify browser-only and combined access modes with the owned image

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
  --access both \
  --service jupyter \
  --helper-mode explicit \
  --group kalebic
```

Browser-only smoke:

```bash
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --access browser \
  --service codeserver \
  --helper-mode explicit \
  --group kalebic
```

For Docker builds from the repository root:

```bash
docker build -f container/Dockerfile -t hpc-dev:latest .
```
