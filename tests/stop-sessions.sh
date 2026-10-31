#!/usr/bin/env bash
#
# Regression test for the "service says stopped but SSH sessions are still
# alive" bug: stop_server() must terminate the listener and every established
# session, not just the process recorded in the PID file.
#
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
PIDS=

cleanup() {
    local pid
    for pid in $PIDS; do
        kill -9 "$pid" 2>/dev/null || true
    done
    exec 9>&- 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

# shellcheck disable=SC1091
. "$ROOT/module/lib.sh"

# The fake daemon must be a real ELF binary: a shell script's /proc/<pid>/exe
# points at the interpreter, not the script.  Copy bash and keep it blocked
# on a FIFO with a read builtin, so the process has no child and its exe path
# is exactly the configured dropbear path.  (Renaming coreutils multicall
# binaries does not work: argv[0] "dropbear" is rejected by coreutils.)
FAKE_KEEPALIVE="$TMP/keepalive"
cp "${BASH:-/bin/bash}" "$TMP/dropbear"
chmod 0755 "$TMP/dropbear"
mkfifo "$FAKE_KEEPALIVE"
exec 9<>"$FAKE_KEEPALIVE"
DROPBEAR=$(readlink -f "$TMP/dropbear")
DROPBEAR_REAL=$DROPBEAR

DATADIR="$TMP/data"
PIDFILE="$DATADIR/dropbear.pid"
LOGFILE="$DATADIR/dropbear.log"
CONFIG="$DATADIR/config"
MODULE_PROP="$TMP/module.prop"
mkdir -p "$DATADIR"
printf 'description=test\n' > "$MODULE_PROP"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

start_fake_dropbear() {
    "$DROPBEAR" -c 'read -r _ < "$1"' _ "$FAKE_KEEPALIVE" &
    FAKE_DROPBEAR_PID=$!
    PIDS="$PIDS $FAKE_DROPBEAR_PID"
}

stop_and_reap() {
    local pid
    for pid in "$@"; do
        wait "$pid" 2>/dev/null || true
        if kill -0 "$pid" 2>/dev/null; then
            fail "dropbear process $pid survived stop_server"
        fi
    done
}

# Listener plus two established sessions.
start_fake_dropbear
listener=$FAKE_DROPBEAR_PID
start_fake_dropbear
session1=$FAKE_DROPBEAR_PID
start_fake_dropbear
session2=$FAKE_DROPBEAR_PID
printf '%s\n' "$listener" > "$PIDFILE"

scan_server_pids || fail "no dropbear processes found"
[ "$SERVER_PID_COUNT" -eq 3 ] || fail "expected 3 dropbear processes, got $SERVER_PID_COUNT"
count_sessions
[ "$SESSION_COUNT" -eq 2 ] || fail "expected 2 sessions, got $SESSION_COUNT"

stop_server || fail "stop_server reported failure"
stop_and_reap "$listener" "$session1" "$session2"
[ ! -e "$PIDFILE" ] || fail "PID file was not removed"
grep -q 'Status: Stopped' "$MODULE_PROP" || fail "module description was not updated"

# Orphaned sessions: the listener is gone and there is no PID file.  The old
# stop script exited immediately in this situation and left them running.
start_fake_dropbear
orphan1=$FAKE_DROPBEAR_PID
start_fake_dropbear
orphan2=$FAKE_DROPBEAR_PID
count_sessions
[ "$SESSION_COUNT" -eq 2 ] || fail "expected 2 orphaned sessions, got $SESSION_COUNT"

stop_server || fail "stop_server did not clean up orphaned sessions"
stop_and_reap "$orphan1" "$orphan2"

# An unrelated process must not be matched by the executable path scan.
start_fake_dropbear
listener=$FAKE_DROPBEAR_PID
printf '%s\n' "$listener" > "$PIDFILE"
cp "$DROPBEAR" "$TMP/bystander"
"$TMP/bystander" -c 'read -r _ < "$1"' _ "$FAKE_KEEPALIVE" &
bystander=$!
PIDS="$PIDS $bystander"

stop_server || fail "stop_server reported failure with a bystander present"
stop_and_reap "$listener"
if ! kill -0 "$bystander" 2>/dev/null; then
    fail "unrelated process was killed by stop_server"
fi
kill "$bystander" 2>/dev/null || true
wait "$bystander" 2>/dev/null || true

printf 'PASS: stop_server terminates the listener and sessions, and leaves unrelated processes alone\n'
