# Phase 1 Service Checklist

1. Start an SSH-first session with `--service jupyter`.
2. Confirm Jupyter metadata is created under the session state directory.
3. Start an SSH-first session with `--service rstudio`.
4. Confirm RStudio runtime state is created under the session state directory.
5. Confirm tunnel commands are printed from `bash bin/hpc-dev tunnel --last`.
6. On the explicit helper path, validate `--access both --service jupyter` on SLURM.
7. Confirm the SLURM `both` tunnel path works from the login host through container `sshd`.
8. If testing locally or on a VM, validate `--access browser --service jupyter`.
9. Confirm Remote-SSH lands in the persistent dev home and that `/workspace` and `/host-home` are both available.
