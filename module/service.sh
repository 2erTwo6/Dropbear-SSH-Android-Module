#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"

load_config || exit 0
[ "$AUTOSTART" = 1 ] || exit 0

"$MODDIR/start.sh" &
