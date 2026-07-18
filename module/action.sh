#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"

if read_pid; then
    "$MODDIR/stop.sh"
    echo "Dropbear SSH stopped"
else
    if "$MODDIR/start.sh"; then
        load_config
        echo "Dropbear SSH started on $LISTEN_ADDRESS:$PORT"
    else
        echo "Dropbear SSH failed to start"
        echo "Log: $LOGFILE"
        exit 1
    fi
fi
