#! /bin/bash

# prepare a trap to remove the port information from the open ports file
cleanup() {
    sed -i "/jupyter ${USER}/d" "$DAT_FILE"
    exit
}
trap cleanup HUP INT TERM

# values that can be set using environmental variables

# name of the file that store the list of open ports for the project
DAT_FILE="${DAT_FILE:-"$HOME/singularity_open_ports.dat"}"
# number of port for the sshd service
JUPYTER_PORT="${JUPYTER_PORT:-"8888"}"

# generate a random token
JUPYTER_TOKEN=$(head /dev/urandom | tr -dc a-z0-9 | head -c 48)

# the number of the port and the token with token are written to $DAT_FILE
echo "jupyter ${USER} ${HOSTNAME}:${JUPYTER_PORT} token=${JUPYTER_TOKEN}" >> "$DAT_FILE"

# start jupyter lab
jupyter lab -y --port="${JUPYTER_PORT}" --ServerApp.token="${JUPYTER_TOKEN}" --notebook-dir="${HOME}" --no-browser
