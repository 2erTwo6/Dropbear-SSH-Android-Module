#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"

stop_server
exit $?
