# SSH/PTTY Recovery Path

When interactive SSH or the VS Code integrated terminal fails inside the owned image, use the control comparison harness before making further SSH server changes.

## Control Comparison

Run this on a compute node or inside an interactive SLURM allocation:

```bash
apptainer build /group/kalebic/Oliviero/envs/control-workbench-base-1.7.0.sif \
  docker://nfdata/workbench:base-1.7.0

bash container/compare-ssh-control.sh \
  --current-image /group/kalebic/Oliviero/envs/hpc-dev-smoke.sif \
  --control-sif /group/kalebic/Oliviero/envs/control-workbench-base-1.7.0.sif \
  --report-root /group/kalebic/Oliviero/hpc-dev-ssh-control/latest \
  --engine apptainer
```

The harness compares:

- the current `hpc-dev` SSH helper/runtime
- the legacy control image/runtime using `run_sshd.sh`

It captures:

- `ssh -T` output
- `ssh -tt` output
- daemon logs
- `/dev/pts` mountinfo
- uid/gid maps and `setgroups`
- `getent passwd` and `getent group tty`
- PTY ownership behavior from a small Python check

The script prints a work root, a `run.log`, and a report directory with `summary.txt` for quick review.
The report is preserved by default so you can inspect the logs after the run, and the
recommended `--report-root` path keeps it on shared storage rather than a node-local `/tmp`.

If you do not want to prebuild the control SIF yourself, you can still point at the Docker
image directly:

```bash
bash container/compare-ssh-control.sh \
  --current-image /group/kalebic/Oliviero/envs/hpc-dev-smoke.sif \
  --control-image docker://nfdata/workbench:base-1.7.0 \
  --report-root /group/kalebic/Oliviero/hpc-dev-ssh-control/latest \
  --engine apptainer
```

That path is more expensive because Apptainer must pull/convert the control image inside the job.

## How To Interpret The Result

Use the control comparison to classify the current blocker:

- `runtime gap`
  - the old control image works, and the main difference is launch environment
  - examples: `exec` vs `run`, `--contain`, home shape, `/tmp`, `/run`, or `/run/user`
- `server behavior gap`
  - both runtimes are close, but the SSH daemon behavior differs
  - examples: PTY ownership, controlling-tty setup, login-record handling
- `architecture gap`
  - the old working path is not equivalent to the current “container daemon owns the terminal PTY” model
  - in this case, stop iterating on SSH daemons and redesign the attach path instead

## Supported Fallback

If the final bounded SSH/PTTY attempt still fails, fall back to the last clearly good pre-RStudio checkpoint:

```bash
git switch -c codex/pre-rstudio-good 5788d53
```

That checkpoint is:

- `5788d53` — `Tighten SLURM UX and SSH workflow support`

From there, preserve or re-apply only the non-problematic improvements:

- stale/dead session handling
- idempotent `stop`
- `cleanup`
- `ssh-config --last`
- startup progress messages

Do not carry forward:

- RStudio image/helper work
- Dropbear/OpenSSH PTY experiments
- any runtime path that still depends on broken interactive in-container PTY ownership

## Fallback Workflow

If fallback is required, the supported workflow becomes:

- `--access both`
- Jupyter
- code-server
- VS Code or code-server editing
- R inside VS Code or code-server
- no RStudio
- no claim of stable interactive in-container SSH/PTTY on this cluster
