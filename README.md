# Dropbear SSH Server for Android

A lightweight KernelSU and Magisk module that runs a Dropbear SSH server as root (UID 0) on arm64 Android devices. It features public-key authentication only and provides secure SSH, SCP, and SFTP support without modifying or mounting the `/system` partition.

---

## Features

- **Root Access:** Runs directly as UID 0 (root).
- **Secure by Default:** Supports public-key authentication only (no password login).
- **Full Suite:** SSH (shell), SCP (secure copy), and SFTP (file transfer) are fully supported.
- **Systemless:** Does not mount or modify the `/system` partition.

---

## Quick Start Guide

### Step 1: Install the Module
1. Download the latest module ZIP file.
2. Flash it using **KernelSU Manager** or **Magisk app**.
3. Reboot your device.

### Step 2: Retrieve Your Private Key
On the first installation, the installer automatically generates a client Ed25519 key pair.
1. Locate the private key file exported on your phone:
   `/sdcard/Download/dropbear-ksu-client-key`
2. **Transfer** this file to your computer.
3. **Important:** Delete this file from your phone's public download folder to keep your device secure.

### Step 3: Set Key Permissions (Linux/macOS)
If you are using a Linux or macOS client, restrict the permissions of your downloaded private key before connecting:
```bash
chmod 600 dropbear-ksu-client-key
```

### Step 4: Connect to Your Phone
Ensure your computer and phone are connected to the same network. Replace `PHONE_IP` with your phone's actual IP address.

*   **SSH Shell Session:**
    ```bash
    ssh -p 2222 -i dropbear-ksu-client-key root@PHONE_IP
    ```
*   **SFTP File Transfer:**
    ```bash
    sftp -P 2222 -i dropbear-ksu-client-key root@PHONE_IP
    ```
    *(Note: SFTP starts in `/sdcard` by default for convenience, but you can still access absolute paths like `/data/local/tmp` if system permissions allow.)*
*   **SCP File Copy:**
    ```bash
    scp -P 2222 -i dropbear-ksu-client-key local_file.txt root@PHONE_IP:/data/local/tmp/
    ```

### Step 5: Managing the Service
To toggle the SSH service on/off or to apply configuration changes, simply click the **Action** button next to this module inside KernelSU Manager or Magisk app.

---

## File Paths

All persistent files are located in `/data/adb/dropbear-ksu/`:

| Path | Description |
| :--- | :--- |
| `/data/adb/dropbear-ksu/config` | Service configuration options |
| `/data/adb/dropbear-ksu/authorized_keys` | Authorized public keys |
| `/data/adb/dropbear-ksu/dropbear_ed25519_host_key`| SSH server host key |
| `/data/adb/dropbear-ksu/dropbear.log` | Daemon log file |

*Note: While SFTP starts in `/sdcard`, regular SSH shell sessions use `/data/adb/dropbear-ksu` as their home directory (`~`).*

---

## Building from Source

The bundled Dropbear binary is compiled with Android NDK r29 (API 23) using source revision `e470317914be7f78791baed62b17578b1c934742` from the upstream `mkj/dropbear` `main` branch.

### Requirements

| Component | Version |
| :--- | :--- |
| Android NDK | r29 |
| Go | 1.25+ |
| Dropbear source | `mkj/dropbear` upstream |
| System tools | `make`, `patch`, `zip` |

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

The compiled binaries will be output to `build/out/`, and the final flashable module ZIP will be created in the repository root.

---

## Changelog

- **v1.3.0**: The module description now reflects the live running status (Running with PID and listen address, or Stopped) shown directly in KernelSU Manager / Magisk app.
- **v1.2.0**: Added support for installation on both KernelSU and Magisk.
- **v1.1.1**: Set the default initial directory of SFTP to `/sdcard`.
- **v1.1.0**: Integrated a static arm64 SFTP subsystem server based on `github.com/pkg/sftp`.
- **v1.0.1**: Removed the `-E` flag for Dropbear builds compiled without syslog support.
