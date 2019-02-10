#!/usr/bin/env fish

set -e ROOTSYS

# Only on macOS
switch (uname)
    # Only if not in the base env (let's be nice)
    case Darwin
        if [ "$CONDA_DEFAULT_ENV" != "base" ]
            if set -q CONDA_BUILD_SYSROOT ; and not set -q SDKROOT
                set -e SDKROOT
            end
        end
end
