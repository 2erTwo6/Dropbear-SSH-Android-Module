#!/system/bin/sh

MODDIR=${0%/*}
"$MODDIR/stop.sh" >/dev/null 2>&1

# Persistent keys and configuration are intentionally retained in
# /data/adb/dropbear-ksu for safe upgrades and stable host identity.
