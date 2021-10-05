#!/usr/bin/env fish

if set -q ROOTSYS
	set -gx CONDA_BACKUP_ROOTSYS "$ROOTSYS"
end

set -gx ROOTSYS "$CONDA_PREFIX"
