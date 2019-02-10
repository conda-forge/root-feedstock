#!/usr/bin/env bash

unset ROOTSYS

# Only on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Only if not in the base env (let's be nice)
    if [ "${CONDA_DEFAULT_ENV}"  != "base" ] ; then
        if [ ! -z "${CONDA_BUILD_SYSROOT}" ] && [ -z "${SDKROOT}" ] ; then
            unset SDKROOT
        fi
    fi
fi
