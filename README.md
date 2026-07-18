# Dropbear SSH Server

KernelSU / Magisk module for arm64 Android. It runs Dropbear as UID 0 with
public-key authentication only and provides SSH, SCP, and SFTP. It does not
mount or modify `/system`.

The bundled Dropbear source revision is `e470317914be7f78791baed62b17578b1c934742`
from upstream `main`, built with Android NDK r29 for API 23.

## Persistent files

- Configuration: `/data/adb/dropbear-ksu/config`
- Authorized keys: `/data/adb/dropbear-ksu/authorized_keys`
- Server host key: `/data/adb/dropbear-ksu/dropbear_ed25519_host_key`
- Log: `/data/adb/dropbear-ksu/dropbear.log`

The installer generates a client Ed25519 key on first installation and exports
the OpenSSH private key to `/sdcard/Download/dropbear-ksu-client-key`. Copy it
off the phone and delete the exported copy from shared storage.

## Connection

```sh
ssh -p 2222 -i dropbear-ksu-client-key root@PHONE_ADDRESS
```

Modern OpenSSH uses SFTP for `scp` by default, which is supported directly:

```sh
scp -P 2222 -i dropbear-ksu-client-key file root@PHONE_ADDRESS:/data/local/tmp/
```

An interactive SFTP session works with:

```sh
sftp -P 2222 -i dropbear-ksu-client-key root@PHONE_ADDRESS
```

SFTP starts in `/sdcard`. This is only the initial working directory, not a
chroot; absolute paths such as `/data/local/tmp` remain accessible subject to
Android filesystem and SELinux permissions. SSH shell sessions still use
`/data/adb/dropbear-ksu` as their home directory.

The action button in KernelSU / Magisk Manager toggles the service:
running becomes stopped, and stopped becomes running. Stop and start after
editing the configuration.

## Changelog

- v1.2.0: Support installation on both KernelSU and Magisk.
- v1.1.1: Set the initial SFTP working directory to `/sdcard`.
- v1.1.0: Add a static arm64 SFTP subsystem server based on `github.com/pkg/sftp`.
- v1.0.1: Do not pass `-E` to builds compiled without syslog support.
