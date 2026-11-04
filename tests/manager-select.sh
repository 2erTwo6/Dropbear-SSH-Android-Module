#!/usr/bin/env bash
#
# Regression test for root-manager selection.  The WebUI must route module
# actions through the manager's own CLI so the action script is detached from
# the manager app cgroup.  APatch/FolkPatch uses /data/adb/apd, KernelSU uses
# ksud, and an APatch install also exports a Magisk-compatible environment, so
# the APatch data directory has to win over a leftover ksud.
#
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)

# shellcheck disable=SC1091
. "$ROOT/module/lib.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

expect() {
    local want=$1
    shift
    local got
    got=$(select_manager "$@")
    if [ "$got" != "$want" ]; then
        fail "select_manager($*) = '$got', want '$want'"
    fi
}

expect '' '' '' ''
expect ksud /x/ksud '' ''
expect apd '' /x/apd ''
expect apd /x/ksud /x/apd 1
expect ksud /x/ksud /x/apd ''

# APatch's action scripts export APATCH=true; the WebUI shell may not, but the
# data directory marker covers that case.
APATCH=true
export APATCH
expect apd /x/ksud /x/apd ''
unset APATCH

printf 'manager selection: ok\n'
