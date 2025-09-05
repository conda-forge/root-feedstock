#!/usr/bin/env csh

if ($?CONDA_BACKUP_ROOTSYS) then
	setenv ROOTSYS "${CONDA_BACKUP_ROOTSYS}"
	unsetenv CONDA_BACKUP_ROOTSYS
else
	unsetenv ROOTSYS
endif
