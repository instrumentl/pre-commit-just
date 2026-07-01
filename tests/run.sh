#!/bin/bash
#
# Test suite for pre-commit-just.sh.
#
# Covers both hooks (format and --check) against the three file states just
# cares about: already-formatted, formatted-but-not-canonically, and invalid
# (a parse error --fmt cannot fix). Sample justfiles are generated at runtime
# so this repo's own whitespace hooks can't mangle them.
#
# Run with: tests/run.sh   (requires `just` on PATH for all but the first test)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../pre-commit-just.sh"

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

pass=0
fail=0

_ok() {
    printf 'ok   - %s\n' "$1"
    pass=$((pass + 1))
}

_fail() {
    printf 'FAIL - %s\n' "$1"
    fail=$((fail + 1))
}

assert_eq() { # expected actual message
    if [ "$1" = "$2" ]; then
        _ok "$3"
    else
        _fail "$3 (expected [$1], got [$2])"
    fi
}

assert_contains() { # haystack needle message
    case "$1" in
        *"$2"*) _ok "$3" ;;
        *) _fail "$3 (output missing [$2])" ;;
    esac
}

assert_unchanged() { # file backup message
    if diff -q "$1" "$2" >/dev/null 2>&1; then
        _ok "$3"
    else
        _fail "$3 (file was modified)"
    fi
}

assert_changed() { # file backup message
    if diff -q "$1" "$2" >/dev/null 2>&1; then
        _fail "$3 (file was not modified)"
    else
        _ok "$3"
    fi
}

# --- sample justfile generators -------------------------------------------

write_formatted() { # path
    cat >"$1" <<'EOF'
default:
    echo "hi"
EOF
}

write_unformatted() { # path
    # Valid, but two-space indent and an extra blank line are not what
    # `just --fmt` produces, so a fmt check reports a diff.
    cat >"$1" <<'EOF'
default:
  echo "hi"


build:
  echo "build"
EOF
}

write_invalid() { # path
    # Duplicate recipe attribute: a parse error --fmt cannot repair.
    cat >"$1" <<'EOF'
[private]
[private]
default:
    echo "hi"
EOF
}

# Fresh temp file seeded by one of the writers above, plus a .orig backup so
# tests can assert whether the hook modified it. Echoes the file path.
seed() { # writer-fn
    local f
    f="$(mktemp "$TMPROOT/justfile.XXXXXX")"
    "$1" "$f"
    cp "$f" "$f.orig"
    printf '%s' "$f"
}

# --- tests -----------------------------------------------------------------

test_no_just() {
    # command -v just fails under an empty PATH; the hook should no-op.
    local f out rc
    f="$(seed write_formatted)"
    out="$(PATH="" "$HOOK" "$f" 2>&1)"
    rc=$?
    assert_eq 0 "$rc" "no just binary: exits 0"
    assert_contains "$out" "no just binary" "no just binary: prints notice"
    assert_unchanged "$f" "$f.orig" "no just binary: leaves file alone"
}

test_check_formatted() {
    local f out rc
    f="$(seed write_formatted)"
    out="$("$HOOK" --check "$f" 2>&1)"
    rc=$?
    assert_eq 0 "$rc" "check/formatted: exits 0"
    assert_unchanged "$f" "$f.orig" "check/formatted: leaves file alone"
}

test_check_unformatted() {
    local f out rc
    f="$(seed write_unformatted)"
    out="$("$HOOK" --check "$f" 2>&1)"
    rc=$?
    assert_eq 1 "$rc" "check/unformatted: exits 1"
    assert_unchanged "$f" "$f.orig" "check/unformatted: does NOT modify the file"
    assert_contains "$out" "is not formatted or is invalid" \
        "check/unformatted: surfaces the error header"
}

test_check_invalid() {
    local f out rc
    f="$(seed write_invalid)"
    out="$("$HOOK" --check "$f" 2>&1)"
    rc=$?
    assert_eq 1 "$rc" "check/invalid: exits 1"
    assert_unchanged "$f" "$f.orig" "check/invalid: does NOT modify the file"
    assert_contains "$out" "private" "check/invalid: surfaces just's parse error"
}

test_format_formatted() {
    local f out rc
    f="$(seed write_formatted)"
    out="$("$HOOK" "$f" 2>&1)"
    rc=$?
    assert_eq 0 "$rc" "format/formatted: exits 0"
    assert_unchanged "$f" "$f.orig" "format/formatted: leaves file alone"
}

test_format_unformatted() {
    local f out rc
    f="$(seed write_unformatted)"
    out="$("$HOOK" "$f" 2>&1)"
    rc=$?
    # Non-zero on purpose: the file was rewritten, so pre-commit reports it.
    assert_eq 1 "$rc" "format/unformatted: exits 1 to flag the change"
    assert_changed "$f" "$f.orig" "format/unformatted: rewrites the file in place"
    assert_contains "$out" "fixing" "format/unformatted: announces the fix"
    if just --fmt --unstable --check -f "$f" >/dev/null 2>&1; then
        _ok "format/unformatted: result is now canonically formatted"
    else
        _fail "format/unformatted: result still fails a fmt check"
    fi
}

test_format_invalid() {
    local f out rc
    f="$(seed write_invalid)"
    out="$("$HOOK" "$f" 2>&1)"
    rc=$?
    assert_eq 1 "$rc" "format/invalid: exits 1"
    assert_unchanged "$f" "$f.orig" "format/invalid: cannot fix, leaves file alone"
    assert_contains "$out" "could not format" "format/invalid: reports the failure"
}

test_multiple_mixed() {
    # A good file alongside a bad one: overall failure, both processed.
    local good bad out rc
    good="$(seed write_formatted)"
    bad="$(seed write_unformatted)"
    out="$("$HOOK" --check "$good" "$bad" 2>&1)"
    rc=$?
    assert_eq 1 "$rc" "multiple/mixed: exits 1 when any file fails"
    assert_unchanged "$good" "$good.orig" "multiple/mixed: good file untouched"
    assert_contains "$out" "$bad" "multiple/mixed: names the failing file"
}

test_no_files() {
    local out rc
    out="$("$HOOK" 2>&1)"
    rc=$?
    assert_eq 0 "$rc" "no file args: exits 0"

    out="$("$HOOK" --check 2>&1)"
    rc=$?
    assert_eq 0 "$rc" "--check with no file args: exits 0"
}

# --- runner ----------------------------------------------------------------

echo "# pre-commit-just.sh"

test_no_just

if command -v just >/dev/null 2>&1; then
    test_check_formatted
    test_check_unformatted
    test_check_invalid
    test_format_formatted
    test_format_unformatted
    test_format_invalid
    test_multiple_mixed
    test_no_files
else
    echo "# skipping just-dependent tests: no just binary on PATH"
fi

echo "# ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
