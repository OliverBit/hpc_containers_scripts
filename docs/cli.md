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
  --service sshd \
  --group kalebic \
  --group testa
```
