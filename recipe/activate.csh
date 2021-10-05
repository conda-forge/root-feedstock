#!/usr/bin/env csh

if ($?ROOTSYS) then
	setenv CONDA_BACKUP_ROOTSYS "${ROOTSYS}"
endif

setenv ROOTSYS "${CONDA_PREFIX}"
