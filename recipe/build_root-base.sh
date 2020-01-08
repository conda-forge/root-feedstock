#!/bin/bash
set -ex

echo $SP_DIR
if python -m site | grep "${SP_DIR}"; then
    echo "Yes"
    exit 0
else
    echo "No"
    exit 1
fi

