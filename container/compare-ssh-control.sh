#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ENGINE="${ENGINE:-auto}"
CURRENT_IMAGE=""
CONTROL_IMAGE="docker://nfdata/workbench:base-1.7.0"
KEEP_TMP="true"
TMP_ROOT=""
REPORT_DIR=""
PIDS=()

note() {
    printf '%s\n' "$*" >&2
}

on_error() {
    local exit_code="$?"
    note "Comparison failed with exit code ${exit_code}."
    if [[ -n "${REPORT_DIR}" && -d "${REPORT_DIR}" ]]
    then
        note "Report root: ${REPORT_DIR}"
        find "${REPORT_DIR%/report}" -maxdepth 3 -type f 2>/dev/null | sort >&2 || true
    fi
    exit "${exit_code}"
}
trap on_error ERR

usage() {
    cat <<'EOF'
Usage:
  container/compare-ssh-control.sh --current-image IMAGE [--control-image IMAGE_OR_URI]
                                  [--engine apptainer|singularity] [--keep-tmp]

Run this on a compute node or inside an interactive SLURM allocation. It compares:
  1. the current hpc-dev SSH helper/runtime
  2. the legacy control image/runtime based on run_sshd.sh

Outputs:
  - a report directory under a temporary root
  - per-runtime diagnostics for SSH command mode, PTY mode, mountinfo, uid/gid maps, and NSS
EOF
}

resolve_engine() {
    if [[ "${ENGINE}" != "auto" ]]
    then
        command -v "${ENGINE}" >/dev/null 2>&1 || {
            echo "Error: requested engine '${ENGINE}' not found" >&2
            exit 1
        }
        printf '%s\n' "${ENGINE}"
        return 0
    fi

    if command -v apptainer >/dev/null 2>&1
    then
        printf '%s\n' "apptainer"
    elif command -v singularity >/dev/null 2>&1
    then
        printf '%s\n' "singularity"
    else
        echo "Error: neither apptainer nor singularity is available" >&2
        exit 1
    fi
}

pick_port() {
    local candidate
    while true
    do
        candidate=$((20000 + RANDOM % 20001))
        if command -v ss >/dev/null 2>&1
        then
            if ss -tan | awk '{print $4}' | grep -Eq "[:.]${candidate}$"
            then
                continue
            fi
        fi
        printf '%s\n' "${candidate}"
        return 0
    done
}

cleanup() {
    local pid
    for pid in "${PIDS[@]-}"
    do
        [[ -n "${pid}" ]] || continue
        kill "${pid}" >/dev/null 2>&1 || true
        wait "${pid}" >/dev/null 2>&1 || true
    done
    if [[ "${KEEP_TMP}" != "true" && -n "${TMP_ROOT}" && -d "${TMP_ROOT}" ]]
    then
        rm -rf "${TMP_ROOT}"
    fi
}
trap cleanup EXIT HUP INT TERM

while [[ $# -gt 0 ]]
do
    case "$1" in
        --current-image) CURRENT_IMAGE="${2:-}"; shift 2 ;;
        --control-image) CONTROL_IMAGE="${2:-}"; shift 2 ;;
        --engine) ENGINE="${2:-}"; shift 2 ;;
        --keep-tmp) KEEP_TMP="true"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Error: unknown option $1" >&2; usage; exit 1 ;;
    esac
done

[[ -n "${CURRENT_IMAGE}" ]] || { usage; exit 1; }
[[ -f "${CURRENT_IMAGE}" ]] || { echo "Error: current image not found: ${CURRENT_IMAGE}" >&2; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "Error: ssh client not found on host" >&2; exit 1; }
command -v ssh-keygen >/dev/null 2>&1 || { echo "Error: ssh-keygen not found on host" >&2; exit 1; }

ENGINE_CMD="$(resolve_engine)"
TMP_ROOT="$(mktemp -d /tmp/hpc-dev-ssh-control.XXXXXX)"
REPORT_DIR="${TMP_ROOT}/report"
mkdir -p "${REPORT_DIR}"
note "Control comparison report root: ${REPORT_DIR}"

SSH_KEY="${TMP_ROOT}/ssh-test-key"
ssh-keygen -q -t ed25519 -N '' -f "${SSH_KEY}" >/dev/null

write_host_diag() {
    local out_file="$1"
    {
        echo "== host id =="
        id
        echo
        echo "== host uid/gid maps =="
        cat /proc/self/uid_map 2>/dev/null || true
        cat /proc/self/gid_map 2>/dev/null || true
        cat /proc/self/setgroups 2>/dev/null || true
        echo
        echo "== host devpts mount =="
        grep ' /dev/pts ' /proc/self/mountinfo || true
        ls -ld /dev/pts /dev/ptmx || true
    } > "${out_file}"
}

write_runtime_diag() {
    local runtime_name="$1"
    local out_file="$2"
    shift 2
    {
        echo "== runtime =="
        printf '%s\n' "${runtime_name}"
        echo
        echo "== diagnostics =="
        "$@" bash -lc '
            id
            echo
            echo "-- binaries --"
            command -v sshd 2>/dev/null || true
            command -v dropbear 2>/dev/null || true
            dropbear -V 2>/dev/null || true
            echo
            echo "-- uid/gid maps --"
            cat /proc/self/uid_map 2>/dev/null || true
            cat /proc/self/gid_map 2>/dev/null || true
            cat /proc/self/setgroups 2>/dev/null || true
            echo
            echo "-- devpts mount --"
            grep " /dev/pts " /proc/self/mountinfo || true
            ls -ld /dev/pts /dev/ptmx /dev/tty 2>/dev/null || true
            echo
            echo "-- NSS --"
            getent passwd "$(id -un)" 2>/dev/null || true
            getent group tty 2>/dev/null || true
            echo
            echo "-- python pty check --"
            if command -v python3 >/dev/null 2>&1; then
            python3 - <<'"'"'PY'"'"'
import os, pty
m, s = pty.openpty()
path = os.ttyname(s)
st = os.stat(path)
print("pty", path)
print("before", {"uid": st.st_uid, "gid": st.st_gid, "mode": oct(st.st_mode & 0o777)})
tests = [
    ("user_gid", os.getuid(), os.getgid()),
    ("user_tty", os.getuid(), 5),
    ("same_owner", st.st_uid, st.st_gid),
]
for label, uid, gid in tests:
    try:
        os.chown(path, uid, gid)
        st2 = os.stat(path)
        print("chown-ok", label, {"uid": st2.st_uid, "gid": st2.st_gid})
    except OSError as e:
        print("chown-fail", label, {"errno": e.errno, "msg": str(e)})
os.close(m)
os.close(s)
PY
            else
                echo "python3 not available"
            fi
        '
    } > "${out_file}" 2>&1
}

run_ssh_checks() {
    local port="$1"
    local out_prefix="$2"
    local target_user
    target_user="$(id -un)"

    ssh \
        -T \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -i "${SSH_KEY}" \
        -p "${port}" \
        "${target_user}@127.0.0.1" \
        'echo ssh-ok && id && pwd' > "${out_prefix}-ssh-T.txt" 2>&1 || true

    ssh \
        -tt \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -i "${SSH_KEY}" \
        -p "${port}" \
        "${target_user}@127.0.0.1" \
        '/bin/bash -il -c "printf pty-ok && pwd && tty || true"' < /dev/null > "${out_prefix}-ssh-tt.txt" 2>&1 || true
}

prepare_current_runtime() {
    note "Preparing current-image runtime ..."
    CURRENT_ROOT="${TMP_ROOT}/current"
    mkdir -p "${CURRENT_ROOT}/state" "${CURRENT_ROOT}/home" "${CURRENT_ROOT}/workspace" "${CURRENT_ROOT}/report"

    local user_name user_uid user_gid user_group
    user_name="$(id -un)"
    user_uid="$(id -u)"
    user_gid="$(id -g)"
    user_group="$(id -gn 2>/dev/null || printf '%s' "${user_name}")"

    cat "${SSH_KEY}.pub" > "${CURRENT_ROOT}/state/authorized_keys"

    cat > "${CURRENT_ROOT}/state/passwd" <<EOF
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
${user_name}:x:${user_uid}:${user_gid}:${user_name}:${CURRENT_ROOT}/home:/bin/bash
EOF

    cat > "${CURRENT_ROOT}/state/group" <<EOF
root:x:0:
${user_group}:x:${user_gid}:${user_name}
tty:x:${user_gid}:${user_name}
nogroup:x:65534:
EOF

    CURRENT_PORT="$(pick_port)"
    "${ENGINE_CMD}" exec \
        --contain \
        -B "${CURRENT_ROOT}/state:/state" \
        -B "${CURRENT_ROOT}/workspace:/workspace" \
        -B "${CURRENT_ROOT}/state/passwd:/etc/passwd" \
        -B "${CURRENT_ROOT}/state/group:/etc/group" \
        -H "${CURRENT_ROOT}/home" \
        "${CURRENT_IMAGE}" \
        hpc-service-sshd.sh \
        --port "${CURRENT_PORT}" \
        --state-dir /state/sshd \
        --metadata-file /state/sshd.env \
        --authorized-keys-file /state/authorized_keys \
        --host-keys-dir /state/hostkeys \
        --bind-address 127.0.0.1 > "${CURRENT_ROOT}/report/daemon.log" 2>&1 &
    PIDS+=("$!")

    for _ in $(seq 1 30)
    do
        [[ -f "${CURRENT_ROOT}/state/sshd.env" ]] && break
        sleep 1
    done
    if [[ ! -f "${CURRENT_ROOT}/state/sshd.env" ]]
    then
        note "Current runtime did not write ssh metadata in time; continuing with logs."
    fi

    note "Capturing current-image diagnostics ..."
    write_runtime_diag \
        "current" \
        "${CURRENT_ROOT}/report/runtime.txt" \
        "${ENGINE_CMD}" exec --contain \
        -B "${CURRENT_ROOT}/state:/state" \
        -B "${CURRENT_ROOT}/workspace:/workspace" \
        -B "${CURRENT_ROOT}/state/passwd:/etc/passwd" \
        -B "${CURRENT_ROOT}/state/group:/etc/group" \
        -H "${CURRENT_ROOT}/home" \
        "${CURRENT_IMAGE}"

    note "Running current-image SSH checks ..."
    run_ssh_checks "${CURRENT_PORT}" "${CURRENT_ROOT}/report/current"
}

prepare_control_runtime() {
    note "Preparing control runtime (${CONTROL_IMAGE}) ..."
    CONTROL_ROOT="${TMP_ROOT}/control"
    mkdir -p "${CONTROL_ROOT}/home/.ssh" "${CONTROL_ROOT}/tmp" "${CONTROL_ROOT}/report"
    cat "${SSH_KEY}.pub" > "${CONTROL_ROOT}/home/.ssh/authorized_keys"

    CONTROL_PORT="$(pick_port)"
    CONTROL_DAT="${CONTROL_ROOT}/home/singularity_open_ports.dat"
    CONTROL_SSH_CONFIG="${CONTROL_ROOT}/home/.sshd-$(id -un)"

    DAT_FILE="${CONTROL_DAT}" \
    SSH_PORT="${CONTROL_PORT}" \
    SSH_CONFIG_PATH="${CONTROL_SSH_CONFIG}" \
    "${ENGINE_CMD}" run \
        -B "${CONTROL_ROOT}/tmp:/tmp" \
        -H "${CONTROL_ROOT}/home" \
        "${CONTROL_IMAGE}" run_sshd.sh > "${CONTROL_ROOT}/report/daemon.log" 2>&1 &
    PIDS+=("$!")

    for _ in $(seq 1 30)
    do
        grep -q "sshd $(id -un)" "${CONTROL_DAT}" 2>/dev/null && break
        sleep 1
    done
    if ! grep -q "sshd $(id -un)" "${CONTROL_DAT}" 2>/dev/null
    then
        note "Control runtime did not register ssh metadata in time; continuing with logs."
    fi

    note "Capturing control diagnostics ..."
    write_runtime_diag \
        "control" \
        "${CONTROL_ROOT}/report/runtime.txt" \
        "${ENGINE_CMD}" exec \
        -B "${CONTROL_ROOT}/tmp:/tmp" \
        -H "${CONTROL_ROOT}/home" \
        "${CONTROL_IMAGE}"

    note "Running control SSH checks ..."
    run_ssh_checks "${CONTROL_PORT}" "${CONTROL_ROOT}/report/control"
}

write_summary() {
    {
        echo "Report root: ${REPORT_DIR}"
        echo
        echo "== host =="
        sed -n '1,120p' "${REPORT_DIR}/host.txt"
        echo
        echo "== current ssh -T =="
        cat "${CURRENT_ROOT}/report/current-ssh-T.txt"
        echo
        echo "== current ssh -tt =="
        cat "${CURRENT_ROOT}/report/current-ssh-tt.txt"
        echo
        echo "== control ssh -T =="
        cat "${CONTROL_ROOT}/report/control-ssh-T.txt"
        echo
        echo "== control ssh -tt =="
        cat "${CONTROL_ROOT}/report/control-ssh-tt.txt"
    } > "${REPORT_DIR}/summary.txt"
}

write_host_diag "${REPORT_DIR}/host.txt"
note "Captured host-side diagnostics."
prepare_current_runtime
prepare_control_runtime
write_summary

echo "Control comparison complete."
echo "Report root: ${REPORT_DIR}"
echo "Summary: ${REPORT_DIR}/summary.txt"
