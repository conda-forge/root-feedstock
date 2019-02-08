#!/usr/bin/env bash

export ROOTSYS="${CONDA_PREFIX}"

# Only on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then

    # Only if not in the base env (let's be nice)
    if [ "${CONDA_DEFAULT_ENV}"  == "base" ] ; then
        if [ -z "${CONDA_BUILD_SYSROOT}" ]  && [ -z "${SDKROOT}" ] ; then
            echo "You will need CONDA_BUILD_SYSROOT or SDKROOT to compile with cling, download the macOS 10.9 SDK"
        fi
    fi
fi

