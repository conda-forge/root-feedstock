#!/usr/bin/env fish

if set -q CONDA_BACKUP_ROOTSYS
	set -gx ROOTSYS "$CONDA_BACKUP_ROOTSYS"
	set -e CONDA_BACKUP_ROOTSYS
else
	set -e ROOTSYS
end
