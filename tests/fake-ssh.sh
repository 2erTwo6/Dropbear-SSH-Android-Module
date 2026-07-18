#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
export DROPBEAR_KSU_SFTP_START_DIR="$ROOT/build/sftp-test-root"
exec "$ROOT/build/test-sftp-server"
