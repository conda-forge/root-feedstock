#!/usr/bin/env bash

# reinstate the backup from outside the environment
if [ ! -z "${CONDA_BACKUP_ROOTSYS}" ]; then
	export ROOTSYS="${CONDA_BACKUP_ROOTSYS}"
	unset CONDA_BACKUP_ROOTSYS
# no backup, just unset
else
	unset ROOTSYS
fi
