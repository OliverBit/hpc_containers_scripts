#!/usr/bin/env bash

hpc_dev_build_bind_args() {
    BIND_ARGS=()
    GROUP_BIND_PATHS=()
    local group_name
    local group_path

    BIND_ARGS+=("-B" "${WORKSPACE_DIR}:${WORKSPACE_MOUNT}")
    BIND_ARGS+=("-B" "${REAL_HOME_DIR}:${REAL_HOME_MOUNT}")
    BIND_ARGS+=("-B" "${DEV_HOME_DIR}:${DEV_HOME_MOUNT}")
    BIND_ARGS+=("-B" "${CONTAINER_TMP_DIR}:/tmp")

    if (( ${#GROUP_NAMES[@]} > 0 ))
    then
        for group_name in "${GROUP_NAMES[@]}"
        do
            group_path="$(hpc_dev_group_path "${group_name}")" || hpc_dev_die "group '${group_name}' is not configured"
            GROUP_BIND_PATHS+=("${group_path}")
            BIND_ARGS+=("-B" "${group_path}:${group_path}")
        done
    fi

    local bind_spec
    if (( ${#BINDS[@]} > 0 ))
    then
        for bind_spec in "${BINDS[@]}"
        do
            BIND_ARGS+=("-B" "${bind_spec}")
        done
    fi
}
