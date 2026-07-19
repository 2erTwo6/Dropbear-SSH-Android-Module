#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"

if ! read_pid; then
    rm -f "$PIDFILE"
    log_message "dropbear is not running"
    exit 0
fi

log_message "stopping dropbear with PID $PID"
kill "$PID" 2>/dev/null

COUNT=0
while kill -0 "$PID" 2>/dev/null && [ "$COUNT" -lt 20 ]; do
    sleep 1
    COUNT=$((COUNT + 1))
done

if kill -0 "$PID" 2>/dev/null; then
    kill -9 "$PID" 2>/dev/null
fi
rm -f "$PIDFILE"
log_message "dropbear stopped"
update_module_description
