#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
: "${DROPBEAR_SOURCE:?Set DROPBEAR_SOURCE to the path of the dropbear source checkout}"
BUILD="$ROOT/build"
SRC="$BUILD/src"
OUT="$BUILD/out"
SFTP_SOURCE="$ROOT/sftp-server"
NDK=${ANDROID_NDK_HOME:?ANDROID_NDK_HOME must point to an Android NDK}
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android23

rm -rf "$BUILD"
mkdir -p "$SRC" "$OUT"
cp -a "$SOURCE/." "$SRC/"

for patch in "$ROOT"/patches/*.patch; do
    patch -d "$SRC" -p1 < "$patch"
done

cat > "$SRC/localoptions.h" <<'EOF'
#undef DROPBEAR_SVR_PASSWORD_AUTH
#define DROPBEAR_SVR_PASSWORD_AUTH 0
#undef DROPBEAR_SVR_PAM_AUTH
#define DROPBEAR_SVR_PAM_AUTH 0
#undef DROPBEAR_CLI_PASSWORD_AUTH
#define DROPBEAR_CLI_PASSWORD_AUTH 0
#undef DROPBEAR_SFTPSERVER
#define DROPBEAR_SFTPSERVER 1
#undef SFTPSERVER_PATH
#define SFTPSERVER_PATH "/data/adb/modules/dropbear-ksu/bin/sftp-server"
#undef DO_MOTD
#define DO_MOTD 0
#undef DEFAULT_ROOT_PATH
#define DEFAULT_ROOT_PATH "/data/adb/modules/dropbear-ksu/bin:/system/bin:/system/xbin:/vendor/bin"
#undef DEFAULT_PATH
#define DEFAULT_PATH "/data/adb/modules/dropbear-ksu/bin:/system/bin:/system/xbin:/vendor/bin"
#define ANDROID_ROOT_HOME "/data/adb/dropbear-ksu"
#define COMPAT_USER_SHELLS "/system/bin/sh","/system/bin/mksh"
EOF

export PATH="$TOOLCHAIN/bin:$PATH"
export CC="$TOOLCHAIN/bin/${TARGET}-clang"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export CPPFLAGS="-DUSE_DEV_PTMX=1"

cd "$SRC"
./configure \
    --host=aarch64-linux-android \
    --enable-static \
    --disable-harden \
    --disable-zlib \
    --disable-pam \
    --disable-syslog \
    --disable-shadow \
    --disable-openpty \
    --disable-lastlog \
    --disable-utmp \
    --disable-utmpx \
    --disable-wtmp \
    --disable-wtmpx \
    --disable-pututline \
    --disable-pututxline \
    --disable-loginfunc

make -j"$(nproc)" PROGRAMS="dropbear dropbearkey dropbearconvert scp" STATIC=1

for program in dropbear dropbearkey dropbearconvert scp; do
    "$STRIP" -o "$OUT/$program" "$SRC/$program"
done

command -v go >/dev/null 2>&1 || {
    printf 'Go is required to build sftp-server\n' >&2
    exit 1
}

cd "$SFTP_SOURCE"
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
    go build -trimpath -ldflags='-s -w -buildid=' -o "$OUT/sftp-server" .

printf 'Built binaries in %s\n' "$OUT"
