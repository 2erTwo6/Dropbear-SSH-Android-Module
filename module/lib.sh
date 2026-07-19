#!/system/bin/sh

MODDIR=${0%/*}
DATADIR=/data/adb/dropbear-ksu
CONFIG="$DATADIR/config"
PIDFILE="$DATADIR/dropbear.pid"
LOGFILE="$DATADIR/dropbear.log"
AUTHORIZED_KEYS="$DATADIR/authorized_keys"
HOSTKEY="$DATADIR/dropbear_ed25519_host_key"
DROPBEAR="$MODDIR/bin/dropbear"
DROPBEARKEY="$MODDIR/bin/dropbearkey"

MODULE_PROP="$MODDIR/module.prop"
BASE_DESCRIPTION="Root Dropbear SSH server for arm64 Android, key authentication only. Supports KernelSU and Magisk."

log_message() {
    mkdir -p "$DATADIR"
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"
}

update_module_description() {
    local status line pid addr port
    if read_pid; then
        pid=$PID
        if load_config 2>/dev/null; then
            addr=$LISTEN_ADDRESS
            port=$PORT
        fi
        [ -n "$addr" ] || addr=?
        [ -n "$port" ] || port=?
        status="Running (PID $pid, $addr:$port)"
    else
        status="Stopped"
        if [ -r "$LOGFILE" ] && ! load_config 2>/dev/null; then
            status="Stopped (invalid config)"
        fi
    fi
    [ -w "$MODULE_PROP" ] || return 0
    grep -q '^description=' "$MODULE_PROP" 2>/dev/null || return 0
    desc_line="description=$BASE_DESCRIPTION | Status: $status"
    awk -v d="$desc_line" '/^description=/{print d; next}1' \
        "$MODULE_PROP" > "$MODULE_PROP.tmp" 2>/dev/null \
        && mv -f "$MODULE_PROP.tmp" "$MODULE_PROP"
}

read_pid() {
    [ -r "$PIDFILE" ] || return 1
    PID=$(cat "$PIDFILE" 2>/dev/null)
    case "$PID" in
        ''|*[!0-9]*) return 1 ;;
    esac
    kill -0 "$PID" 2>/dev/null || return 1

    EXE=$(readlink "/proc/$PID/exe" 2>/dev/null)
    [ "$EXE" = "$DROPBEAR" ] || [ "$EXE" = "$DROPBEAR (deleted)" ]
}

rotate_log() {
    [ -f "$LOGFILE" ] || return 0
    SIZE=$(wc -c < "$LOGFILE" 2>/dev/null)
    case "$SIZE" in
        ''|*[!0-9]*) return 0 ;;
    esac
    if [ "$SIZE" -ge 1048576 ]; then
        mv -f "$LOGFILE" "$LOGFILE.1"
    fi
}

load_config() {
    LISTEN_ADDRESS=127.0.0.1
    PORT=2222
    KEEPALIVE=60
    IDLE_TIMEOUT=0
    ALLOW_PORT_FORWARDING=0
    AUTOSTART=1

    [ -r "$CONFIG" ] || return 1

    while IFS='=' read -r KEY VALUE; do
        case "$KEY" in
            LISTEN_ADDRESS) LISTEN_ADDRESS=$VALUE ;;
            PORT) PORT=$VALUE ;;
            KEEPALIVE) KEEPALIVE=$VALUE ;;
            IDLE_TIMEOUT) IDLE_TIMEOUT=$VALUE ;;
            ALLOW_PORT_FORWARDING) ALLOW_PORT_FORWARDING=$VALUE ;;
            AUTOSTART) AUTOSTART=$VALUE ;;
        esac
    done < "$CONFIG"

    case "$LISTEN_ADDRESS" in
        ''|*[!A-Za-z0-9._:\[\]-]*) return 1 ;;
    esac
    case "$PORT" in
        ''|*[!0-9]*) return 1 ;;
    esac
    case "$KEEPALIVE" in
        ''|*[!0-9]*) return 1 ;;
    esac
    case "$IDLE_TIMEOUT" in
        ''|*[!0-9]*) return 1 ;;
    esac
    case "$ALLOW_PORT_FORWARDING" in
        0|1) ;;
        *) return 1 ;;
    esac
    case "$AUTOSTART" in
        0|1) ;;
        *) return 1 ;;
    esac
    [ "$PORT" -ge 1 ] 2>/dev/null && [ "$PORT" -le 65535 ] 2>/dev/null
}
