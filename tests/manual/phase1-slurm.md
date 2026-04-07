# Phase 1 SLURM Checklist

1. Use `--partition cpu-interactive` or the site-appropriate interactive queue.
2. Start a supported SLURM session with `bash bin/hpc-dev start --mode slurm ... --access both --service jupyter` or `--service codeserver`.
3. Confirm that a batch script and logs are created inside the session state directory.
4. Confirm that tunnel and SSH-config information resolves from session-local metadata, not from the project directory.
5. Confirm that `bash bin/hpc-dev status --last` reports the runtime state cleanly.
6. Confirm that `bash bin/hpc-dev stop --last` cancels the SLURM job and is idempotent after a manual `scancel`.
7. Confirm that `bash bin/hpc-dev cleanup --dry-run` only targets stale session state by default.
