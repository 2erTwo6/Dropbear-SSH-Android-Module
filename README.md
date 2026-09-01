# Dropbear SSH Server for Android

A lightweight, systemless [KernelSU](https://github.com/tiann/KernelSU) / [Magisk](https://github.com/topjohnwu/Magisk) module that runs a [Dropbear](https://github.com/mkj/dropbear) SSH server as root (UID 0) on arm64 Android devices.

It provides **public-key authentication only**, with SSH (shell), SCP (secure copy), and SFTP (file transfer) support, and does **not** mount or modify the `/system` partition.

---

## Highlights

- **Runs as root (UID 0):** full system access over SSH (subject to Android/SELinux policy).
- **Secure by default:**
  - Password authentication is compiled out (`DROPBEAR_SVR_PASSWORD_AUTH = 0`).
  - Only the Ed25519 client key generated at install time is authorized by default.
  - Port forwarding is disabled by default.
- **Full file-transfer suite:** SSH shell, SCP, and a static arm64 SFTP subsystem (`github.com/pkg/sftp`).
- **Systemless:** installs under `/data/adb/modules/dropbear-ksu`; keeps writable data under `/data/adb/dropbear-ksu`.
- **KernelSU WebUI:** live status, start/stop/restart, key regeneration, listen address/port configuration, and one-click log clearing.
- **Magisk action button:** one-tap start/stop of the SSH service.

---

## Compatibility

| Requirement | Value |
| :--- | :--- |
| Android version | Android 5.0+ (API 21+) |
| Architecture | arm64 only |
| Root solution | KernelSU or Magisk |
| Dropbear source | upstream `mkj/dropbear`, revision `e470317914be7f78791baed62b17578b1c934742` |
| Android NDK (build only) | r29 (API 23 toolchain) |
| Go (build only) | 1.25+ |

---

## Installation

### 1. Flash the module

1. Download the latest `dropbear-ksu-v*-arm64.zip` from the Releases page.
2. Flash it with **KernelSU Manager** or the **Magisk app**.
3. Reboot the device.

### 2. Choose the listening mode (first install only)

During the first installation the installer asks for the default listen address:

| Key | Listen address | Description |
| :--- | :--- | :--- |
| **Vol+** | `0.0.0.0:2222` | Listen on all interfaces (LAN/Wi-Fi accessible) |
| **Vol-** | `127.0.0.1:2222` | Local device only (safest default) |

> If volume-key detection is unavailable, the installer falls back to the local-only default. The setting is written to `/data/adb/dropbear-ksu/config` and can be changed later via the WebUI or by editing the file.

### 3. Retrieve the generated client private key

On the first install, the installer generates an Ed25519 client key pair and exports the OpenSSH-format private key to:

```text
/sdcard/Download/dropbear-ksu-client-key
```

1. Copy this file to your computer.
2. **Delete it from `/sdcard/Download` afterwards** — that is a public, world-readable download folder.

> The matching public key is installed as the only entry in `/data/adb/dropbear-ksu/authorized_keys`.

---

## Connecting

Make sure your computer and phone can reach each other over the network (for `0.0.0.0` installs, this usually means the same Wi-Fi/LAN). Replace `PHONE_IP` with the phone's actual IP address.

> **Linux/macOS:** after copying the key to your computer, tighten its permissions first, otherwise OpenSSH will refuse to use it (`UNPROTECTED PRIVATE KEY FILE`):
>
> ```bash
> chmod 600 dropbear-ksu-client-key
> ```
>
> Windows OpenSSH does not enforce POSIX permissions; just make sure the key file is only readable by your user.

```bash
# SSH shell (home directory is /data/adb/dropbear-ksu)
ssh -p 2222 -i dropbear-ksu-client-key root@PHONE_IP

# SFTP file transfer (starts in /sdcard by default)
sftp -P 2222 -i dropbear-ksu-client-key root@PHONE_IP

# SCP file copy
scp -P 2222 -i dropbear-ksu-client-key local_file.txt root@PHONE_IP:/data/local/tmp/
```

Notes:

- SFTP starts in `/sdcard`, but absolute paths such as `/data/local/tmp` still work if Android/SELinux allows access.
- OpenSSH SCP clients since 9.0 use the SFTP protocol by default, which is supported by this module. To force the legacy SCP protocol instead of SFTP, add `-O`.
- If you changed the port in the config, use that port instead of `2222`.

---

## Service Management

### KernelSU Manager

- **WebUI:** open the module card / WebUI button. The WebUI offers:
  - Live status (running state, PID, listen address, port, timeouts, port-forwarding flag, latest daemon log).
  - Start / stop / restart shortcuts.
  - Ed25519 **client key regeneration** (backs up the previous keys, installs the new public key into `authorized_keys`, and exports the new OpenSSH private key).
  - Ed25519 **server host-key regeneration** (backs up the previous host key and restarts Dropbear if running).
  - **Listen address / port configuration** (edits `/data/adb/dropbear-ksu/config`; restarts Dropbear if running).
  - **One-click log clearing** (empties `dropbear.log` and the rotated `dropbear.log.1`).
- **Action button:** toggles the SSH service on/off.

### Magisk app

- Tap the **Action** button next to the module to toggle the SSH service on/off.

### From an `adb shell` (with root)

```bash
su -c '/data/adb/modules/dropbear-ksu/action.sh'
```

This prints the action result and uses the same start/stop logic as the manager Action button.

### Automatic start at boot

The module ships a `service.sh` that starts Dropbear at boot when `AUTOSTART=1` in the configuration (the default).

---

## Configuration

The persistent configuration file is:

```text
/data/adb/dropbear-ksu/config
```

| Key | Default | Description |
| :--- | :--- | :--- |
| `LISTEN_ADDRESS` | `127.0.0.1` | IPv4 address, hostname, or bracketed IPv6 address to listen on. Use `0.0.0.0` for all interfaces. |
| `PORT` | `2222` | TCP listen port, `1`–`65535`. |
| `KEEPALIVE` | `60` | Seconds between keep-alive messages (`-K`). `0` disables. |
| `IDLE_TIMEOUT` | `0` | Disconnect after this many idle seconds (`-I`). `0` disables. |
| `ALLOW_PORT_FORWARDING` | `0` | `1` enables TCP forwarding; `0` disables local and remote forwarding (`-j -k`). |
| `AUTOSTART` | `1` | `1` starts the service automatically at boot; `0` disables auto-start. |

After editing the file manually, restart the service or run the module Action button so changes take effect. The WebUI `get-config` / `set-config` commands provide a safer, validated way to edit `LISTEN_ADDRESS` and `PORT`.

---

## WebUI Reference

The WebUI is a single self-contained page at:

```text
/data/adb/modules/dropbear-ksu/webroot/index.html
```

It talks to `/data/adb/modules/dropbear-ksu/webui.sh` through the KernelSU `ksu.exec` API. The backend supports these subcommands:

| Command | Description |
| :--- | :--- |
| `status` | Print status, configuration, and the latest daemon log. |
| `start` | Start Dropbear. |
| `stop` | Stop Dropbear. |
| `restart` | Restart Dropbear. |
| `get-config` | Print the current validated configuration. |
| `set-config <address> <port>` | Update `LISTEN_ADDRESS` and `PORT`, then restart if running. |
| `regen-client-keys` | Generate and export a new Ed25519 client key pair. |
| `regen-host-key` | Generate and install a new Ed25519 server host key. |
| `clear-log` | Clear the daemon log (`dropbear.log` and rotated `dropbear.log.1`). |

---

## File Paths

### Persistent data — `/data/adb/dropbear-ksu/`

| Path | Description |
| :--- | :--- |
| `/data/adb/dropbear-ksu/config` | Service configuration options. |
| `/data/adb/dropbear-ksu/authorized_keys` | Authorized public keys. |
| `/data/adb/dropbear-ksu/dropbear_ed25519_host_key` | SSH server host key (Ed25519). |
| `/data/adb/dropbear-ksu/dropbear.pid` | PID file for the running daemon. |
| `/data/adb/dropbear-ksu/dropbear.log` | Daemon log file (rotated at 1 MiB to `dropbear.log.1`). |
| `/data/adb/dropbear-ksu/backups/` | Timestamped backups created by WebUI key-regeneration actions. |

### Module files — `/data/adb/modules/dropbear-ksu/`

| Path | Description |
| :--- | :--- |
| `bin/` | Static arm64 binaries: `dropbear`, `dropbearkey`, `dropbearconvert`, `scp`, `sftp-server`. |
| `module.prop` | Module metadata; the description shows the live running status. |
| `config.default` | Factory-default configuration template. |
| `customize.sh` | Installer script. |
| `service.sh` | Boot-time service script (honors `AUTOSTART`). |
| `start.sh` / `stop.sh` / `action.sh` | Service control scripts. |
| `webui.sh` | KernelSU WebUI backend. |
| `webroot/index.html` | KernelSU WebUI page. |
| `uninstall.sh` | Uninstall hook (stops the service, keeps persistent data). |

> **Uninstalling the module stops the SSH service but intentionally keeps `/data/adb/dropbear-ksu/`** so re-installations preserve your configuration, authorized keys, and host identity.

---

## Security Notes

- The private key exported to `/sdcard/Download/dropbear-ksu-client-key` is the only copy of the client key. **Move it off the phone and delete the phone copy.**
- If the key is lost, use the KernelSU WebUI **“regenerate client key pair”** action; this replaces the old authorized public key with the new one.
- If you suspect the host key is compromised, regenerate it from the WebUI. Note that clients will then warn about a changed host key until their `known_hosts` entry is updated.
- `ALLOW_PORT_FORWARDING` is disabled by default; only enable it if you need TCP forwarding.
- Listening on `0.0.0.0` exposes the SSH service to the current network. Use a firewall, trust the network, or prefer `127.0.0.1` when remote access is not required.
- The daemon runs as root and SSH sessions have root privileges. Protect your client private key accordingly.

---

## Building from Source

### Requirements

| Component | Version / Notes |
| :--- | :--- |
| Android NDK | r29 (the build uses the `aarch64-linux-android23` toolchain). |
| Go | 1.25+ (for the static `sftp-server` binary). |
| Dropbear source | upstream `mkj/dropbear` at revision `e470317914be7f78791baed62b17578b1c934742`. |
| System tools | `make`, `patch`, `zip` (`unzip` for testing). |
| Host OS | Linux x86_64 (the build script assumes NDK prebuilt `linux-x86_64`). |

### Build Steps

```bash
# 1. Clone this repository
git clone https://github.com/2erTwo6/Dropbear-SSH-Android-Module.git
cd Dropbear-SSH-Android-Module

# 2. Clone Dropbear upstream source
git clone https://github.com/mkj/dropbear.git /tmp/dropbear-upstream

# 3. Build all binaries
ANDROID_NDK_HOME=/path/to/android-ndk-r29 \
DROPBEAR_SOURCE=/tmp/dropbear-upstream \
GOFLAGS=-mod=mod \
    bash build.sh

# 4. Package the module ZIP
DROPBEAR_SOURCE=/tmp/dropbear-upstream bash package.sh
```

The build script:

1. Copies the Dropbear source into `build/src/`.
2. Applies the patches from `patches/`.
3. Writes `localoptions.h` (password auth off, static SFTP server path, Android root paths, etc.).
4. Cross-compiles `dropbear`, `dropbearkey`, `dropbearconvert`, and `scp` with the Android NDK.
5. Builds `sftp-server` as a static Linux arm64 Go binary.

Outputs:

| Path | Description |
| :--- | :--- |
| `build/out/` | Compiled binaries (`dropbear`, `dropbearkey`, `dropbearconvert`, `scp`, `sftp-server`). |
| `dropbear-ksu-v1.4.2-arm64.zip` | Flashable module package (also contains `legal/` license copies). |

### Running the Tests

The repository includes shell-syntax checks and an SFTP protocol smoke test (also run by CI):

```bash
# Shell syntax check
for script in build.sh package.sh module/*.sh tests/*.sh; do
    sh -n "$script" && echo "syntax ok: $script"
done

# Build a host sftp-server test fixture, then run a batch SFTP smoke test
mkdir -p build/sftp-test-root
cp README.md build/sftp-test-root/README.md
cd sftp-server
GOFLAGS=-mod=mod CGO_ENABLED=0 go build -trimpath \
    -ldflags='-s -w -buildid=' \
    -o "$PWD/../build/test-sftp-server" .
cd ..
rm -f /tmp/dropbear-ksu-sftp-test-README.md
sftp -S "$PWD/tests/fake-ssh.sh" -b tests/sftp.batch host.invalid
test -f /tmp/dropbear-ksu-sftp-test-README.md
```

---

## Changelog

- **v1.4.2**: Added a one-click “clear log” action to the WebUI; it empties both the current daemon log and the rotated log file.
- **v1.4.0**: Added a KernelSU WebUI. The management console supports status detection, quick start/stop/restart, client/server key pair regeneration, and listen IP:port configuration.
- **v1.3.0**: The module description now reflects the live running status (Running with PID and listen address, or Stopped) shown directly in KernelSU Manager / Magisk app.
- **v1.2.0**: Added support for installation on both KernelSU and Magisk.
- **v1.1.1**: Set the default initial directory of SFTP to `/sdcard`.
- **v1.1.0**: Integrated a static arm64 SFTP subsystem server based on `github.com/pkg/sftp`.
- **v1.0.1**: Removed the `-E` flag for Dropbear builds compiled without syslog support.

---

## License

Dropbear is distributed under its upstream MIT-style license; the bundled `sftp-server` uses `github.com/pkg/sftp` and its Go dependencies. License copies are included in the module ZIP under `legal/`.
