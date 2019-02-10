#!/usr/bin/env fish

set -x ROOTSYS "$CONDA_PREFIX"

# Only on macOS
switch (uname)
    # Only if not in the base env (let's be nice)
    case Darwin
        if [ "$CONDA_DEFAULT_ENV" != "base" ]
            if not set -q CONDA_BUILD_SYSROOT ; and not set -q SDKROOT
                echo "You will need CONDA_BUILD_SYSROOT or SDKROOT to compile with cling, download the macOS 10.9 SDK"
            end
        end
end
