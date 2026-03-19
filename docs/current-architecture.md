# Current Legacy Architecture Snapshot

Legacy root scripts:

- `slurm_docker_run.txt`
- `local_docker_run.txt`
- `run_sshd.txt`
- `run_jupyterlab.txt`
- `run_rstudioserver.txt`

Important legacy assumptions:

- `PROJECT_DIR` is simultaneously workspace, effective home backing store, and runtime state directory
- helper scripts default to `$HOME/singularity_open_ports.dat`
- ssh host keys live under project-local `.sshd-$USER`
- project-local `.ssh/authorized_keys` is used for container ssh login
- RStudio runtime state is created under project-local `.rserver-$USER`
- a single bind path is exposed as the old `-B` interface
- `/group/testa` is hardcoded as the default extra bind
