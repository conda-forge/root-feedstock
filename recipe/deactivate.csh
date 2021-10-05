#!/usr/bin/env csh

if ($?ROOTSYS) then
	setenv ROOTSYS "${CONDA_BACKUP_ROOTSYS}"
	unsetenv CONDA_BACKUP_ROOTSYS
else
	unsetenv ROOTSYS
endif
