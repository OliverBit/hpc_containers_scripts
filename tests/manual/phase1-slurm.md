# Phase 1 SLURM Checklist

1. Use `--partition cpu-interactive` or the site-appropriate interactive queue.
2. Start an ssh-only SLURM session with `bash bin/hpc-dev start --mode slurm ...`.
3. Confirm that a batch script and logs are created inside the session state directory.
4. Confirm that SSH connection information resolves from session-local metadata, not from the project directory.
5. Confirm that `bash bin/hpc-dev stop --last` cancels the SLURM job.
