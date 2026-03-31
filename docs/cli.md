# hpc-dev CLI

Primary entrypoint:

```bash
bash bin/hpc-dev plan  --mode local|slurm --image IMAGE --workspace PATH [options]
bash bin/hpc-dev start --mode local|slurm --image IMAGE --workspace PATH [options]
bash bin/hpc-dev status --last
bash bin/hpc-dev stop   --last
bash bin/hpc-dev ssh    --last
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

Access modes:

- `--access ssh`: start `sshd`, optionally add browser services
- `--access browser`: browser-facing services only; requires `--helper-mode explicit`
- `--access both`: `sshd` plus browser-facing services; requires `--helper-mode explicit`

If `--access` is omitted, `ssh` is the default.

Examples:

```bash
# SSH-first remote development with Jupyter available through the container SSH tunnel
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --service jupyter \
  --helper-mode explicit \
  --group kalebic

# Browser-only Jupyter session
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --access browser \
  --service jupyter \
  --helper-mode explicit \
  --group kalebic

# SSH plus code-server together
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
- use `--helper-mode explicit` only with the owned image path
- use `--access browser` and `--service codeserver` only on the explicit helper path
