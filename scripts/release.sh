#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) ARCH="$ARCH_RAW" ;;
esac

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$ROOT_DIR/release/${STAMP}-${OS}-${ARCH}"
mkdir -p "$OUT_DIR"

echo "[release] building haskell ftf"
cabal build --builddir=.cabal-ftf
FTF_BIN="$(cabal list-bin --builddir=.cabal-ftf ftf)"

echo "[release] building rust ftf-verify"
(
  cd rust/ftf-verify
  cargo build --release
)

FTF_OUT="$OUT_DIR/ftf-${OS}-${ARCH}"
VERIFY_OUT="$OUT_DIR/ftf-verify-${OS}-${ARCH}"
cp "$FTF_BIN" "$FTF_OUT"
cp "$ROOT_DIR/rust/ftf-verify/target/release/ftf-verify" "$VERIFY_OUT"
chmod 755 "$FTF_OUT" "$VERIFY_OUT"

if command -v sha256sum >/dev/null 2>&1; then
  (
    cd "$OUT_DIR"
    sha256sum "$(basename "$FTF_OUT")" "$(basename "$VERIFY_OUT")" > SHA256SUMS
  )
elif command -v shasum >/dev/null 2>&1; then
  (
    cd "$OUT_DIR"
    shasum -a 256 "$(basename "$FTF_OUT")" "$(basename "$VERIFY_OUT")" > SHA256SUMS
  )
else
  echo "[release] missing sha256 tool (sha256sum/shasum)" >&2
  exit 1
fi

echo "[release] wrote artifacts to $OUT_DIR"
ls -lh "$OUT_DIR"
