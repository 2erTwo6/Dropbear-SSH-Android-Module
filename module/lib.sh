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

# /proc/<pid>/exe reports the resolved path.  Keep both forms so a MODDIR
# reached through a symlink still matches the running daemon.
DROPBEAR_REAL=$(readlink -f "$DROPBEAR" 2>/dev/null) || DROPBEAR_REAL=$DROPBEAR
case "$DROPBEAR_REAL" in
    /*) ;;
    *) DROPBEAR_REAL=$DROPBEAR ;;
esac

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
        count_sessions
        if [ "$SESSION_COUNT" -gt 0 ]; then
            status="Stopped ($SESSION_COUNT SSH session(s) still active)"
        fi
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
    [ "$EXE" = "$DROPBEAR" ] || [ "$EXE" = "$DROPBEAR (deleted)" ] \
        || [ "$EXE" = "$DROPBEAR_REAL" ] || [ "$EXE" = "$DROPBEAR_REAL (deleted)" ]
}

# Dropbear forks one child per accepted connection and that child calls
# setsid().  Established sessions are therefore independent processes: they
# are not part of the listener's process group and are not reachable through
# the PID file.  Scan /proc for this module's binary to find the listener and
# every live session, including sessions orphaned by an earlier crash.
scan_server_pids() {
    local proc pid exe
    SERVER_PIDS=
    SERVER_PID_COUNT=0
    for proc in /proc/[0-9]*; do
        [ -d "$proc" ] || continue
        pid=${proc##*/}
        exe=$(readlink "$proc/exe" 2>/dev/null) || continue
        case "$exe" in
            "$DROPBEAR"|"$DROPBEAR (deleted)"|"$DROPBEAR_REAL"|"$DROPBEAR_REAL (deleted)")
                SERVER_PIDS="$SERVER_PIDS $pid"
                SERVER_PID_COUNT=$((SERVER_PID_COUNT + 1))
                ;;
        esac
    done
    SERVER_PIDS=${SERVER_PIDS# }
    [ "$SERVER_PID_COUNT" -gt 0 ]
}

# Established sessions are all dropbear processes except the listener
# recorded in the PID file.
count_sessions() {
    SESSION_COUNT=0
    if scan_server_pids; then
        SESSION_COUNT=$SERVER_PID_COUNT
        if read_pid 2>/dev/null; then
            case " $SERVER_PIDS " in
                *" $PID "*) SESSION_COUNT=$((SESSION_COUNT - 1)) ;;
            esac
        fi
    fi
    return 0
}

# Stop the listener and every established session.  A plain "kill $PID" only
# closes the listening socket: sessions keep running as root and the WebUI
# reports "stopped" while they are still usable.  Returns non-zero if any
# dropbear process survives.
stop_server() {
    local waited
    waited=0

    if ! scan_server_pids; then
        rm -f "$PIDFILE"
        log_message "dropbear is not running"
        update_module_description
        return 0
    fi

    log_message "stopping dropbear ($SERVER_PID_COUNT process(es)): $SERVER_PIDS"

    # Re-scan and signal on every round so a connection accepted just before
    # the listener exits cannot survive the shutdown.
    while scan_server_pids; do
        kill $SERVER_PIDS 2>/dev/null
        if [ "$waited" -ge 10 ]; then
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done

    if scan_server_pids; then
        log_message "force killing dropbear: $SERVER_PIDS"
        kill -9 $SERVER_PIDS 2>/dev/null
        sleep 1
    fi

    if scan_server_pids; then
        log_message "failed to stop dropbear; still running: $SERVER_PIDS"
        update_module_description
        return 1
    fi

    rm -f "$PIDFILE"
    log_message "dropbear stopped"
    update_module_description
    return 0
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
