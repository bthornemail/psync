#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

METAVERSE_KIT_DIR="${METAVERSE_KIT_DIR:-/home/main/devops/metaverse-kit}"
TOOL="$METAVERSE_KIT_DIR/tools/mv-evidence-surface/index.js"

[[ -f "$TOOL" ]] || { echo "ERROR: mv-evidence-surface tool not found: $TOOL" >&2; exit 2; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

expect_fail_none() {
  local bin="$1"
  if node "$TOOL" wave31-verify \
    --surface dev-docs/wave31/inputs/evidence-surface.chords.v0.json \
    --emitter dev-docs/wave31/inputs/evidence-surface.frames.leds240.esp32.v0.ndjson \
    --uart-crc none \
    --in-bin "$bin" \
    --receipt-out "$TMP_DIR/receipt.json" \
    --verify-out "$TMP_DIR/verify.json" >/dev/null 2>&1; then
    echo "ERROR: expected failure for $bin" >&2
    exit 2
  fi
}

expect_fail_crc() {
  local bin="$1"
  if node "$TOOL" wave31-verify \
    --surface dev-docs/wave31/inputs/evidence-surface.chords.v0.json \
    --emitter dev-docs/wave31/inputs/evidence-surface.frames.leds240.esp32.v0.ndjson \
    --uart-crc crc8-xor-v0 \
    --in-bin "$bin" \
    --receipt-out "$TMP_DIR/receipt.json" \
    --verify-out "$TMP_DIR/verify.json" >/dev/null 2>&1; then
    echo "ERROR: expected failure for $bin (crc mode)" >&2
    exit 2
  fi
}

expect_fail_none dev-docs/wave31/must-reject/truncated.bin
expect_fail_none dev-docs/wave31/must-reject/trailing-garbage.bin
expect_fail_none dev-docs/wave31/must-reject/bad-header.bin
expect_fail_none dev-docs/wave31/must-reject/wrong-length.bin
expect_fail_none dev-docs/wave31/must-reject/reordered.bin
expect_fail_crc  dev-docs/wave31/must-reject/crc-mismatch.bin

echo "ok wave31 device parity must-reject"
