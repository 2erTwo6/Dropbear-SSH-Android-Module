#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"

load_config || {
    update_module_description
    exit 0
}

if [ "$AUTOSTART" = 1 ]; then
    update_module_description
    "$MODDIR/start.sh" &
else
    update_module_description
fi
