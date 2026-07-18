#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
STAGE="$ROOT/build/package"
OUTPUT="$ROOT/dropbear-ksu-v1.2.0-arm64.zip"

rm -rf "$STAGE" "$OUTPUT"
mkdir -p "$STAGE/bin"
cp -a "$ROOT/module/." "$STAGE/"
cp "$ROOT/build/out/dropbear" "$STAGE/bin/"
cp "$ROOT/build/out/dropbearkey" "$STAGE/bin/"
cp "$ROOT/build/out/dropbearconvert" "$STAGE/bin/"
cp "$ROOT/build/out/scp" "$STAGE/bin/"
cp "$ROOT/build/out/sftp-server" "$STAGE/bin/"
mkdir -p "$STAGE/legal"
cp /var/home/liu/tmp1/dropbear/LICENSE "$STAGE/legal/dropbear-LICENSE"
cp "$ROOT/sftp-server/LICENSE.pkg-sftp" "$STAGE/legal/pkg-sftp-LICENSE"
cp "$ROOT/sftp-server/LICENSE.kr-fs" "$STAGE/legal/kr-fs-LICENSE"
cp "$ROOT/sftp-server/LICENSE.x-crypto" "$STAGE/legal/x-crypto-LICENSE"

chmod 0755 "$STAGE"/*.sh "$STAGE/bin"/*
chmod 0644 "$STAGE/module.prop" "$STAGE/config.default"
chmod 0644 "$STAGE/legal/dropbear-LICENSE"
chmod 0644 "$STAGE/legal/pkg-sftp-LICENSE"
chmod 0644 "$STAGE/legal/kr-fs-LICENSE"
chmod 0644 "$STAGE/legal/x-crypto-LICENSE"

(
    cd "$STAGE"
    zip -9 -r "$OUTPUT" .
)

printf 'Created %s\n' "$OUTPUT"
