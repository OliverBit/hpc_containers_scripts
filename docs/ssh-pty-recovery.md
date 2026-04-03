# SSH/PTTY Recovery Path

When interactive SSH or the VS Code integrated terminal fails inside the owned image, use the control comparison harness before making further SSH server changes.

## Control Comparison

Run this on a compute node or inside an interactive SLURM allocation:

```bash
bash container/compare-ssh-control.sh \
  --current-image /group/kalebic/Oliviero/envs/hpc-dev-smoke.sif \
  --control-image docker://nfdata/workbench:base-1.7.0 \
  --engine apptainer \
  --keep-tmp
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

The script prints a report directory and writes a `summary.txt` there for quick review.
The report is preserved by default so you can inspect the logs after the run.

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
