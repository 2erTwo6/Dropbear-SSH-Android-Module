# Dropbear SSH Server / Dropbear SSH 服务器

KernelSU / Magisk module for arm64 Android. It runs Dropbear as UID 0 with
public-key authentication only and provides SSH, SCP, and SFTP. It does not
mount or modify `/system`.

适用于 arm64 Android 的 KernelSU / Magisk 模块。以 UID 0 运行 Dropbear，
仅支持公钥认证，提供 SSH、SCP 和 SFTP 功能。不会挂载或修改 `/system`。

The bundled Dropbear source revision is `e470317914be7f78791baed62b17578b1c934742`
from upstream `main`, built with Android NDK r29 for API 23.

内置的 Dropbear 源码版本为上游 `main` 分支的 `e470317914be7f78791baed62b17578b1c934742`，
使用 Android NDK r29 针对 API 23 编译。

## Build from source / 从源码构建

**Requirements / 依赖要求**

| Component / 组件              | Version / 版本        |
|-------------------------------|----------------------|
| Android NDK                   | r29                  |
| Go                            | 1.25+                |
| Dropbear source / 源码        | `mkj/dropbear` 上游  |
| System tools / 系统工具       | `make`, `patch`, `zip` |

**Steps / 构建步骤**

```sh
# 1. Clone this repo / 克隆本仓库
git clone https://github.com/2erTwo6/Dropbear-SSH-Android-Module.git
cd Dropbear-SSH-Android-Module

# 2. Clone Dropbear source / 克隆 Dropbear 源码
git clone https://github.com/mkj/dropbear.git /tmp/dropbear-upstream

# 3. Build all binaries / 编译所有二进制文件
ANDROID_NDK_HOME=/path/to/android-ndk-r29 \
DROPBEAR_SOURCE=/tmp/dropbear-upstream \
GOFLAGS=-mod=mod \
    bash build.sh

# 4. Package the module ZIP / 打包模块 ZIP
DROPBEAR_SOURCE=/tmp/dropbear-upstream bash package.sh
```

Build output is at `build/out/`. The final ZIP is at the repo root.

编译输出位于 `build/out/`。最终的 ZIP 文件在仓库根目录。

## Persistent files / 持久化文件

- Configuration / 配置文件: `/data/adb/dropbear-ksu/config`
- Authorized keys / 授权密钥: `/data/adb/dropbear-ksu/authorized_keys`
- Server host key / 服务器主机密钥: `/data/adb/dropbear-ksu/dropbear_ed25519_host_key`
- Log / 日志: `/data/adb/dropbear-ksu/dropbear.log`

The installer generates a client Ed25519 key on first installation and exports
the OpenSSH private key to `/sdcard/Download/dropbear-ksu-client-key`. Copy it
off the phone and delete the exported copy from shared storage.

安装程序在首次安装时生成客户端 Ed25519 密钥，并将 OpenSSH 私钥导出到
`/sdcard/Download/dropbear-ksu-client-key`。请将该文件复制到电脑上，
然后删除共享存储中导出的副本。

## Connection / 连接

```sh
ssh -p 2222 -i dropbear-ksu-client-key root@PHONE_ADDRESS
```

Modern OpenSSH uses SFTP for `scp` by default, which is supported directly:

现代 OpenSSH 默认使用 SFTP 进行 `scp` 传输，可直接使用：

```sh
scp -P 2222 -i dropbear-ksu-client-key file root@PHONE_ADDRESS:/data/local/tmp/
```

An interactive SFTP session works with:

交互式 SFTP 会话使用方式：

```sh
sftp -P 2222 -i dropbear-ksu-client-key root@PHONE_ADDRESS
```

SFTP starts in `/sdcard`. This is only the initial working directory, not a
chroot; absolute paths such as `/data/local/tmp` remain accessible subject to
Android filesystem and SELinux permissions. SSH shell sessions still use
`/data/adb/dropbear-ksu` as their home directory.

SFTP 起始目录为 `/sdcard`。这只是初始工作目录，并非 chroot；
绝对路径（如 `/data/local/tmp`）仍可访问，受 Android 文件系统和 SELinux 权限限制。
SSH shell 会话仍使用 `/data/adb/dropbear-ksu` 作为 home 目录。

The action button in KernelSU / Magisk Manager toggles the service:
running becomes stopped, and stopped becomes running. Stop and start after
editing the configuration.

KernelSU / Magisk Manager 中的操作按钮可切换服务状态：
运行中变为已停止，已停止变为运行中。修改配置后请重启服务。

## Changelog / 更新日志

- v1.2.0: Support installation on both KernelSU and Magisk. / 支持在 KernelSU 和 Magisk 上安装。
- v1.1.1: Set the initial SFTP working directory to `/sdcard`. / 将 SFTP 初始工作目录设为 `/sdcard`。
- v1.1.0: Add a static arm64 SFTP subsystem server based on `github.com/pkg/sftp`. / 新增基于 `github.com/pkg/sftp` 的静态 arm64 SFTP 子系统服务器。
- v1.0.1: Do not pass `-E` to builds compiled without syslog support. / 不再向未编译 syslog 支持的构建传递 `-E` 参数。
