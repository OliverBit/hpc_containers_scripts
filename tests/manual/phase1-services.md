# Phase 1 Service Checklist

1. Start an SSH-first session with `--service jupyter`.
2. Confirm Jupyter metadata is created under the session state directory.
3. Start an SSH-first session with `--service rstudio`.
4. Confirm RStudio runtime state is created under the session state directory.
5. Confirm tunnel commands are printed from `bash bin/hpc-dev tunnel --last`.
6. On the explicit helper path, validate `--access browser --service jupyter`.
7. On the explicit helper path, validate `--access both --service jupyter`.
