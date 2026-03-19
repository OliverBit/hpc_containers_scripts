# Phase 1 Service Checklist

1. Start a session with `--service sshd --service jupyter`.
2. Confirm Jupyter metadata is created under the session state directory.
3. Start a session with `--service sshd --service rstudio`.
4. Confirm RStudio runtime state is created under the session state directory.
5. Confirm tunnel commands are printed from `bash bin/hpc-dev tunnel --last`.
