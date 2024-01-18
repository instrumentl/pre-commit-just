#!/bin/bash

set -euo pipefail

if ! command -v just /dev/null 2>&1; then
    echo >&2 "no just binary found; not running"
    exit 0
fi

status=0

for file in "$@"; do
    if ! just --fmt --unstable --check -f "$file" >/dev/null 2>&1; then
        echo >&2 "fixing ${file}"
        just --fmt --unstable -f "$file" >/dev/null 2>&1
        status=1
    fi
done

exit $status
