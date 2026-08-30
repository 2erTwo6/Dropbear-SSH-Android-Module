#!/system/bin/sh

DATADIR=/data/adb/dropbear-ksu
CONFIG="$DATADIR/config"
AUTHORIZED_KEYS="$DATADIR/authorized_keys"
HOSTKEY="$DATADIR/dropbear_ed25519_host_key"
CLIENT_DROPBEAR="$TMPDIR/dropbear_ksu_client"
CLIENT_OPENSSH="$TMPDIR/dropbear_ksu_client.openssh"
CLIENT_PUBLIC="$TMPDIR/dropbear_ksu_client.pub"
EXPORT_DIR=/sdcard/Download
EXPORT_KEY="$EXPORT_DIR/dropbear-ksu-client-key"

ID=dropbear-ksu
NAME="Dropbear SSH, SCP and SFTP"
ui_print ""
ui_print "========================================"
ui_print "  $NAME"
ui_print "  Android arm64, root login, key only"
ui_print "========================================"
ui_print ""

if [ "$KSU" = true ]; then
    ui_print "[*] Running under KernelSU"
elif [ -n "$MAGISK_VER_CODE" ]; then
    ui_print "[*] Running under Magisk $MAGISK_VER"
else
    abort "KernelSU or Magisk is required"
fi
[ "$ARCH" = arm64 ] || abort "Unsupported architecture: $ARCH (arm64 required)"
[ "$API" -ge 21 ] || abort "Android API 21 or newer is required"

choose_listen_mode() {
    if type chooseport >/dev/null 2>&1; then
        chooseport
        return $?
    fi
    if [ -x /system/bin/getevent ]; then
        while true; do
            EVENT=$(/system/bin/getevent -qlc 1 2>/dev/null)
            case "$EVENT" in
                *KEY_VOLUMEUP*DOWN*) return 0 ;;
                *KEY_VOLUMEDOWN*DOWN*) return 1 ;;
            esac
        done
    fi
    ui_print "Volume key detection unavailable; using local-only mode."
    return 1
}

set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm "$MODPATH/start.sh" 0 0 0755
set_perm "$MODPATH/stop.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/lib.sh" 0 0 0755
set_perm "$MODPATH/webui.sh" 0 0 0755
set_perm "$MODPATH/config.default" 0 0 0644
set_perm "$MODPATH/module.prop" 0 0 0644

mkdir -p "$DATADIR"
chmod 700 "$DATADIR"

if [ ! -f "$CONFIG" ]; then
    ui_print "Choose the default listening mode:"
    ui_print "  Vol+ : LAN/all interfaces (0.0.0.0:2222)"
    ui_print "  Vol- : local device only (127.0.0.1:2222)"

    LISTEN_ADDRESS=127.0.0.1
    if choose_listen_mode; then
        LISTEN_ADDRESS=0.0.0.0
    fi

    cp "$MODPATH/config.default" "$CONFIG"
    sed -i "s/^LISTEN_ADDRESS=.*/LISTEN_ADDRESS=$LISTEN_ADDRESS/" "$CONFIG"
    chmod 600 "$CONFIG"
    ui_print "Selected: $LISTEN_ADDRESS:2222"
else
    ui_print "Keeping existing configuration: $CONFIG"
fi

if [ ! -s "$HOSTKEY" ]; then
    ui_print "Generating Ed25519 server host key..."
    "$MODPATH/bin/dropbearkey" -t ed25519 -f "$HOSTKEY" >/dev/null 2>&1 \
        || abort "Failed to generate the server host key"
fi
chmod 600 "$HOSTKEY"

if [ ! -s "$AUTHORIZED_KEYS" ]; then
    ui_print "Generating a one-time Ed25519 client key..."
    "$MODPATH/bin/dropbearkey" -t ed25519 -f "$CLIENT_DROPBEAR" >/dev/null 2>&1 \
        || abort "Failed to generate the client key"
    "$MODPATH/bin/dropbearkey" -y -f "$CLIENT_DROPBEAR" \
        | sed -n '/^ssh-ed25519 /p' > "$CLIENT_PUBLIC"
    [ -s "$CLIENT_PUBLIC" ] || abort "Failed to extract the client public key"

    "$MODPATH/bin/dropbearconvert" dropbear openssh \
        "$CLIENT_DROPBEAR" "$CLIENT_OPENSSH" >/dev/null 2>&1 \
        || abort "Failed to convert the client key to OpenSSH format"

    mkdir -p "$EXPORT_DIR"
    cp "$CLIENT_OPENSSH" "$EXPORT_KEY" \
        || abort "Failed to export the client private key to $EXPORT_KEY"
    chmod 600 "$EXPORT_KEY" 2>/dev/null || true
    cp "$CLIENT_PUBLIC" "$AUTHORIZED_KEYS" \
        || abort "Failed to install the client public key"
    rm -f "$CLIENT_DROPBEAR" "$CLIENT_OPENSSH" "$CLIENT_PUBLIC"

    ui_print ""
    ui_print "IMPORTANT: client private key exported to:"
    ui_print "  $EXPORT_KEY"
    ui_print "Copy it to your computer, then delete it from the phone."
else
    ui_print "Keeping existing authorized_keys: $AUTHORIZED_KEYS"
fi
chmod 600 "$AUTHORIZED_KEYS"

ui_print ""
ui_print "Configuration: $CONFIG"
ui_print "Persistent data: $DATADIR"
if [ "$KSU" = true ]; then
    ui_print "Tap the module card or WebUI icon in KernelSU Manager to open WebUI."
    ui_print "The action button still toggles SSH start/stop."
else
    ui_print "Use the action button in Magisk Manager to start/stop SSH."
fi
ui_print "SFTP is enabled; modern scp works without -O."
ui_print ""
