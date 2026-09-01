#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"

case "${DROPBEAR_WEBUI_CMD:-}" in
    start)
        if "$MODDIR/start.sh"; then
            load_config
            echo "Dropbear SSH started on $LISTEN_ADDRESS:$PORT"
        else
            update_module_description
            echo "Dropbear SSH failed to start"
            echo "Log: $LOGFILE"
            exit 1
        fi
        exit 0
        ;;
    stop)
        "$MODDIR/stop.sh"
        echo "Dropbear SSH stopped"
        exit 0
        ;;
    restart)
        "$MODDIR/stop.sh" >/dev/null 2>&1
        if "$MODDIR/start.sh"; then
            load_config
            echo "Dropbear SSH restarted on $LISTEN_ADDRESS:$PORT"
        else
            update_module_description
            echo "Dropbear SSH failed to restart"
            echo "Log: $LOGFILE"
            exit 1
        fi
        exit 0
        ;;
esac

if read_pid; then
    "$MODDIR/stop.sh"
    echo "Dropbear SSH stopped"
else
    if "$MODDIR/start.sh"; then
        load_config
        echo "Dropbear SSH started on $LISTEN_ADDRESS:$PORT"
    else
        update_module_description
        echo "Dropbear SSH failed to start"
        echo "Log: $LOGFILE"
        exit 1
    fi
fi
