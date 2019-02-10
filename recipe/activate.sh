#!/usr/bin/env bash

export ROOTSYS="${CONDA_PREFIX}"

# Only on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Only if not in the base env (let's be nice)
    if [ "${CONDA_DEFAULT_ENV}"  != "base" ] ; then
        if [ -z "${CONDA_BUILD_SYSROOT}" ] ; then
            echo "WARNING: Compiling likely won't work unless you: download the macOS 10.9 SDK, set CONDA_BUILD_SYSROOT and reactivate the environment."
            echo "You can probably ignore this warning and just omit + or ++ when executing ROOT macros."
        else
            export SDKROOT="${CONDA_BUILD_SYSROOT}"
        fi
    fi
fi
