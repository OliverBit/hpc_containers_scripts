# Phase 1 Local Checklist

1. Configure `~/.config/hpc-dev/config.env`.
2. Run `bash bin/hpc-dev plan --mode local --image IMAGE --workspace PATH --group kalebic`.
3. Start an ssh-only session.
4. Confirm that no `.ssh`, `.sshd-*`, `.rserver-*`, or `singularity_open_ports.dat` is written into the project.
5. Confirm cache growth lands in the configured cache directory rather than home defaults.
