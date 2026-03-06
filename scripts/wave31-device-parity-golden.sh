#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

METAVERSE_KIT_DIR="${METAVERSE_KIT_DIR:-/home/main/devops/metaverse-kit}"
TOOL="$METAVERSE_KIT_DIR/tools/mv-evidence-surface/index.js"

[[ -f "$TOOL" ]] || { echo "ERROR: mv-evidence-surface tool not found: $TOOL" >&2; exit 2; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node "$TOOL" wave31-verify \
  --surface dev-docs/wave31/inputs/evidence-surface.chords.v0.json \
  --emitter dev-docs/wave31/inputs/evidence-surface.frames.leds240.esp32.v0.ndjson \
  --uart-crc none \
  --in-bin dev-docs/wave31/inputs/evidence-surface.uart.esp32.v0.bin \
  --receipt-out "$TMP_DIR/receipt.json" \
  --verify-out "$TMP_DIR/verify.json"

cmp -s "$TMP_DIR/receipt.json" dev-docs/wave31/golden/hardware-decode-receipt.v0.json || {
  echo "ERROR: wave31 golden receipt mismatch" >&2
  exit 2
}
cmp -s "$TMP_DIR/verify.json" dev-docs/wave31/golden/frame-verify-result.v0.json || {
  echo "ERROR: wave31 golden frame verify mismatch" >&2
  exit 2
}

echo "ok wave31 device parity golden"
