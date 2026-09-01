#!/system/bin/sh
#
# dropbear-ksu WebUI backend.
#
# The WebUI (webroot/index.html) calls this script through the KernelSU
# JavaScript API (ksu.exec).  Each subcommand prints simple KEY=VALUE lines
# so the web page can parse the output without a JSON parser.
#

MODDIR=${0%/*}
. "$MODDIR/lib.sh"

CMD=$1
[ $# -gt 0 ] && shift

EXPORT_DIR=/sdcard/Download
EXPORT_KEY="$EXPORT_DIR/dropbear-ksu-client-key"
BACKUP_DIR="$DATADIR/backups"

KSUD=/data/adb/ksud
[ -x "$KSUD" ] || KSUD=/data/adb/ksu/bin/ksud
MODULE_ID=${MODDIR##*/}

# Start/stop/restart must run through "ksud module action" so KernelSU
# detaches the service from the WebUI/manager process group and cgroup.
# A daemon started directly from ksu.exec inherits the manager's cgroup:
# it gets frozen when the manager goes to the background (connections time
# out) and is killed when the manager is reaped.
run_module_action() {
    DROPBEAR_WEBUI_CMD=$1
    export DROPBEAR_WEBUI_CMD
    if [ -x "$KSUD" ]; then
        "$KSUD" module action "$MODULE_ID"
    else
        case "$1" in
            start) "$MODDIR/start.sh" ;;
            stop) "$MODDIR/stop.sh" ;;
            restart)
                "$MODDIR/stop.sh" >/dev/null 2>&1
                "$MODDIR/start.sh"
                ;;
        esac
    fi
}

validate_address() {
    case "$1" in
        ''|*[!A-Za-z0-9._:\[\]-]*) return 1 ;;
    esac
    return 0
}

validate_port() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$1" -ge 1 ] 2>/dev/null && [ "$1" -le 65535 ] 2>/dev/null
}

print_status() {
    if read_pid; then
        echo "RUNNING=1"
        echo "PID=$PID"
    else
        echo "RUNNING=0"
        echo "PID="
    fi

    if load_config 2>/dev/null; then
        echo "CONFIG_OK=1"
    else
        echo "CONFIG_OK=0"
        LISTEN_ADDRESS='?'
        PORT='?'
        KEEPALIVE='?'
        IDLE_TIMEOUT='?'
        ALLOW_PORT_FORWARDING='?'
        AUTOSTART='?'
    fi

    echo "ADDRESS=$LISTEN_ADDRESS"
    echo "PORT=$PORT"
    echo "KEEPALIVE=$KEEPALIVE"
    echo "IDLE_TIMEOUT=$IDLE_TIMEOUT"
    echo "ALLOW_PORT_FORWARDING=$ALLOW_PORT_FORWARDING"
    echo "AUTOSTART=$AUTOSTART"
    echo "CONFIG_FILE=$CONFIG"
    echo "AUTHORIZED_KEYS=$AUTHORIZED_KEYS"
    echo "HOSTKEY=$HOSTKEY"
    echo "LOGFILE=$LOGFILE"
    echo "PIDFILE=$PIDFILE"

    echo "---LOG---"
    if [ -r "$LOGFILE" ]; then
        tail -n 60 "$LOGFILE" 2>/dev/null
    else
        echo "(no log file)"
    fi
}

do_status() {
    print_status
}

do_start() {
    run_module_action start
    if read_pid; then
        echo "STARTED=1"
    else
        echo "STARTED=0"
        echo "ERROR=Failed to start service"
        return 1
    fi
}

do_stop() {
    run_module_action stop
    if read_pid; then
        echo "STOPPED=0"
        echo "ERROR=Failed to stop service"
        return 1
    else
        echo "STOPPED=1"
    fi
}

do_restart() {
    run_module_action restart
    if read_pid; then
        echo "RESTARTED=1"
    else
        echo "RESTARTED=0"
        echo "ERROR=Failed to restart service"
        return 1
    fi
}

do_get_config() {
    if ! load_config; then
        echo "ERROR=invalid configuration in $CONFIG"
        return 1
    fi
    echo "ADDRESS=$LISTEN_ADDRESS"
    echo "PORT=$PORT"
    echo "KEEPALIVE=$KEEPALIVE"
    echo "IDLE_TIMEOUT=$IDLE_TIMEOUT"
    echo "ALLOW_PORT_FORWARDING=$ALLOW_PORT_FORWARDING"
    echo "AUTOSTART=$AUTOSTART"
}

do_set_config() {
    NEW_ADDRESS=$1
    NEW_PORT=$2

    if ! validate_address "$NEW_ADDRESS"; then
        echo "ERROR=Invalid listen address: $NEW_ADDRESS"
        return 1
    fi
    if ! validate_port "$NEW_PORT"; then
        echo "ERROR=Invalid port: $NEW_PORT"
        return 1
    fi

    mkdir -p "$DATADIR"
    chmod 700 "$DATADIR"

    if [ ! -r "$CONFIG" ]; then
        cp "$MODDIR/config.default" "$CONFIG"
    fi

    if grep -q '^LISTEN_ADDRESS=' "$CONFIG" 2>/dev/null; then
        sed -i "s/^LISTEN_ADDRESS=.*/LISTEN_ADDRESS=$NEW_ADDRESS/" "$CONFIG"
    else
        echo "LISTEN_ADDRESS=$NEW_ADDRESS" >> "$CONFIG"
    fi

    if grep -q '^PORT=' "$CONFIG" 2>/dev/null; then
        sed -i "s/^PORT=.*/PORT=$NEW_PORT/" "$CONFIG"
    else
        echo "PORT=$NEW_PORT" >> "$CONFIG"
    fi

    chmod 600 "$CONFIG"

    if ! load_config; then
        echo "ERROR=Updated configuration is invalid"
        return 1
    fi

    echo "ADDRESS=$LISTEN_ADDRESS"
    echo "PORT=$PORT"

    if read_pid; then
        run_module_action restart >/dev/null 2>&1
        if read_pid; then
            echo "SERVICE_RESTARTED=1"
        else
            echo "SERVICE_RESTARTED=0"
            echo "ERROR=Configuration saved, but service restart failed"
            return 1
        fi
    else
        update_module_description
        echo "SERVICE_RESTARTED=0"
    fi
}

do_regen_host_key() {
    TMP_HOST="$DATADIR/.webui-host-key"

    mkdir -p "$DATADIR" "$BACKUP_DIR"
    chmod 700 "$DATADIR"
    rm -f "$TMP_HOST"

    if [ ! -x "$DROPBEARKEY" ]; then
        echo "ERROR=dropbearkey is missing"
        return 1
    fi

    if ! "$DROPBEARKEY" -t ed25519 -f "$TMP_HOST" >/dev/null 2>&1; then
        echo "ERROR=Failed to generate a new server host key"
        rm -f "$TMP_HOST"
        return 1
    fi

    TS=$(date '+%Y%m%d-%H%M%S')
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    if [ -s "$HOSTKEY" ]; then
        cp "$HOSTKEY" "$BACKUP_DIR/hostkey.$TS" 2>/dev/null
    fi

    if ! mv -f "$TMP_HOST" "$HOSTKEY" 2>/dev/null; then
        cp "$TMP_HOST" "$HOSTKEY" || {
            echo "ERROR=Failed to install the new server host key"
            rm -f "$TMP_HOST"
            return 1
        }
        rm -f "$TMP_HOST"
    fi
    chmod 600 "$HOSTKEY"

    echo "HOSTKEY=$HOSTKEY"
    echo "BACKUP_DIR=$BACKUP_DIR"

    if read_pid; then
        run_module_action restart >/dev/null 2>&1
        if read_pid; then
            echo "SERVICE_RESTARTED=1"
        else
            echo "SERVICE_RESTARTED=0"
            echo "ERROR=Host key generated, but service restart failed"
            return 1
        fi
    else
        update_module_description
        echo "SERVICE_RESTARTED=0"
    fi
}

do_clear_log() {
    mkdir -p "$DATADIR"
    chmod 700 "$DATADIR"

    if ! : > "$LOGFILE" 2>/dev/null; then
        echo "ERROR=Failed to clear $LOGFILE"
        return 1
    fi
    if [ -f "$LOGFILE.1" ]; then
        : > "$LOGFILE.1" 2>/dev/null || {
            echo "ERROR=Failed to clear $LOGFILE.1"
            return 1
        }
    fi

    echo "CLEARED=1"
    echo "LOGFILE=$LOGFILE"
}

do_regen_client_keys() {
    TMP_CLIENT="$DATADIR/.webui-client-dropbear"
    TMP_OPENSSH="$DATADIR/.webui-client-openssh"
    TMP_PUBLIC="$DATADIR/.webui-client-pub"

    mkdir -p "$DATADIR" "$EXPORT_DIR"
    chmod 700 "$DATADIR"
    rm -f "$TMP_CLIENT" "$TMP_OPENSSH" "$TMP_PUBLIC"

    if [ ! -x "$DROPBEARKEY" ] || [ ! -x "$MODDIR/bin/dropbearconvert" ]; then
        echo "ERROR=dropbearkey or dropbearconvert is missing"
        return 1
    fi

    if ! "$DROPBEARKEY" -t ed25519 -f "$TMP_CLIENT" >/dev/null 2>&1; then
        echo "ERROR=Failed to generate a new client key"
        rm -f "$TMP_CLIENT" "$TMP_OPENSSH" "$TMP_PUBLIC"
        return 1
    fi

    "$DROPBEARKEY" -y -f "$TMP_CLIENT" 2>/dev/null \
        | sed -n '/^ssh-ed25519 /p' > "$TMP_PUBLIC"
    if [ ! -s "$TMP_PUBLIC" ]; then
        echo "ERROR=Failed to extract the new client public key"
        rm -f "$TMP_CLIENT" "$TMP_OPENSSH" "$TMP_PUBLIC"
        return 1
    fi

    if ! "$MODDIR/bin/dropbearconvert" dropbear openssh \
        "$TMP_CLIENT" "$TMP_OPENSSH" >/dev/null 2>&1; then
        echo "ERROR=Failed to convert the new client key to OpenSSH format"
        rm -f "$TMP_CLIENT" "$TMP_OPENSSH" "$TMP_PUBLIC"
        return 1
    fi

    TS=$(date '+%Y%m%d-%H%M%S')
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    if [ -s "$AUTHORIZED_KEYS" ]; then
        cp "$AUTHORIZED_KEYS" "$BACKUP_DIR/authorized_keys.$TS" 2>/dev/null
    fi
    if [ -s "$EXPORT_KEY" ]; then
        cp "$EXPORT_KEY" "$BACKUP_DIR/client-key.$TS" 2>/dev/null
    fi

    cp "$TMP_PUBLIC" "$AUTHORIZED_KEYS" || {
        echo "ERROR=Failed to install the new client public key"
        rm -f "$TMP_CLIENT" "$TMP_OPENSSH" "$TMP_PUBLIC"
        return 1
    }
    chmod 600 "$AUTHORIZED_KEYS"

    rm -f "$EXPORT_KEY"
    cp "$TMP_OPENSSH" "$EXPORT_KEY" || {
        echo "ERROR=Failed to export the new client private key to $EXPORT_KEY"
        rm -f "$TMP_CLIENT" "$TMP_OPENSSH" "$TMP_PUBLIC"
        return 1
    }
    chmod 600 "$EXPORT_KEY" 2>/dev/null

    rm -f "$TMP_CLIENT" "$TMP_OPENSSH" "$TMP_PUBLIC"

    echo "EXPORT=$EXPORT_KEY"
    echo "AUTHORIZED_KEYS=$AUTHORIZED_KEYS"
    echo "BACKUP_DIR=$BACKUP_DIR"

    if read_pid; then
        run_module_action restart >/dev/null 2>&1
        if read_pid; then
            echo "SERVICE_RESTARTED=1"
        else
            echo "SERVICE_RESTARTED=0"
            echo "ERROR=Keys generated, but service restart failed"
            return 1
        fi
    else
        update_module_description
        echo "SERVICE_RESTARTED=0"
    fi
}

case "$CMD" in
    status)
        do_status
        ;;
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    restart)
        do_restart
        ;;
    get-config)
        do_get_config
        ;;
    set-config)
        do_set_config "$1" "$2"
        ;;
    regen-client-keys)
        do_regen_client_keys
        ;;
    regen-host-key)
        do_regen_host_key
        ;;
    clear-log)
        do_clear_log
        ;;
    *)
        echo "ERROR=Unknown command: $CMD"
        echo "COMMANDS=status|start|stop|restart|get-config|set-config|regen-client-keys|regen-host-key|clear-log"
        exit 1
        ;;
esac
