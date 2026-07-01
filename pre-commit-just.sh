#!/bin/bash

set -euo pipefail

if ! command -v just >/dev/null 2>&1; then
    echo >&2 "no just binary found; not running"
    exit 0
fi

# With --check, report unformatted or invalid justfiles and fail without
# modifying them (the check-justfile hook). Without it, auto-format in place
# (the format-justfile hook).
check_only=0
if [ "${1:-}" = "--check" ]; then
    check_only=1
    shift
fi

status=0

for file in "$@"; do
    if just --fmt --unstable --check -f "$file" >/dev/null 2>&1; then
        continue
    fi

    if [ "$check_only" -eq 1 ]; then
        # Surface just's own output: a formatting diff, or a parse error such
        # as "Extraneous attribute" that --fmt cannot fix.
        echo >&2 "error: ${file} is not formatted or is invalid:"
        just --fmt --unstable --check -f "$file" >&2 || true
    else
        echo >&2 "fixing ${file}"
        # If just cannot format the file (e.g. a parse error), let its message
        # through instead of hiding it.
        if ! just --fmt --unstable -f "$file"; then
            echo >&2 "error: could not format ${file} (see above)"
        fi
    fi

    status=1
done

exit $status
