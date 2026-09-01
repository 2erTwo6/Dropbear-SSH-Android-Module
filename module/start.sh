#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"

if read_pid; then
    log_message "dropbear already running with PID $PID"
    exit 0
fi
rm -f "$PIDFILE"

if ! load_config; then
    log_message "invalid configuration in $CONFIG"
    exit 1
fi

if [ ! -x "$DROPBEAR" ] || [ ! -s "$HOSTKEY" ] || [ ! -s "$AUTHORIZED_KEYS" ]; then
    log_message "required binary or key file is missing"
    exit 1
fi

mkdir -p "$DATADIR"
chmod 700 "$DATADIR"
chmod 600 "$HOSTKEY" "$AUTHORIZED_KEYS"

set -- -F \
    -r "$HOSTKEY" \
    -D "$DATADIR" \
    -p "$LISTEN_ADDRESS:$PORT" \
    -P "$PIDFILE" \
    -K "$KEEPALIVE" \
    -I "$IDLE_TIMEOUT"

if [ "$ALLOW_PORT_FORWARDING" != 1 ]; then
    set -- "$@" -j -k
fi

rotate_log
log_message "starting dropbear on $LISTEN_ADDRESS:$PORT"
"$DROPBEAR" "$@" < /dev/null >> "$LOGFILE" 2>&1 &
PID=$!
printf '%s\n' "$PID" > "$PIDFILE"
sleep 1

if ! kill -0 "$PID" 2>/dev/null; then
    rm -f "$PIDFILE"
    log_message "dropbear failed to start"
    exit 1
fi

log_message "dropbear started with PID $PID"
update_module_description
