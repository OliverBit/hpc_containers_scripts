# Phase 1 Local Checklist

1. Configure `~/.config/hpc-dev/config.env`.
2. Run `bash bin/hpc-dev plan --mode local --image IMAGE --workspace PATH --group kalebic`.
3. Start a supported local session with either `--access browser --service jupyter` or `--access both --service codeserver`.
4. Confirm that no `.ssh`, `.sshd-*`, `.rserver-*`, or `singularity_open_ports.dat` is written into the project.
5. Confirm the printed URL or tunnel hints match the selected service.
6. Confirm cache growth lands in the configured cache directory rather than home defaults.
7. Run `bash bin/hpc-dev cleanup --dry-run` and confirm only stale local session state would be removed.
8. Treat `jupyter` and `codeserver` as the supported local services on this branch. `RStudio` remains disabled.
