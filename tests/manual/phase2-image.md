# Phase 2 Owned Image Checklist

1. Build the image:

```bash
bash container/build-apptainer.sh /path/to/hpc-dev.sif
```

2. Run the smoke test:

```bash
bash container/smoke-test-image.sh --image /path/to/hpc-dev.sif
```

3. Confirm the smoke test reports:

- helper help checks pass
- `sshd`, `jupyter`, and `python3` exist
- Jupyter metadata is created

4. If `rserver` is not present yet, treat that as expected until the site-specific RStudio install is added.

5. After the image smoke test passes, validate wrapper integration:

```bash
bash bin/hpc-dev start \
  --mode slurm \
  --image /path/to/hpc-dev.sif \
  --workspace /path/to/project \
  --service sshd \
  --service jupyter \
  --helper-mode explicit \
  --group kalebic
```
