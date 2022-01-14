#!/usr/bin/env bash

# preserve the user's existing setting
if [ ! -z "${ROOTSYS+x}" ]; then
	export CONDA_BACKUP_ROOTSYS="${ROOTSYS}"
fi

export ROOTSYS="${CONDA_PREFIX}"
