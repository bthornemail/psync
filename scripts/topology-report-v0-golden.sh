#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# TODO(v0): replace with canonical fixture + waveform-core invocation.
SUBJECT="12200000000000000000000000000000000000000000000000000000000000000000"
INPUT_DIGEST="sha256:0000000000000000000000000000000000000000000000000000000000000000"

OUT_A="$(mktemp)"
OUT_B="$(mktemp)"
trap 'rm -f "$OUT_A" "$OUT_B"' EXIT

adapters/topology-report-v0/emit_topology_report.sh "$SUBJECT" "$INPUT_DIGEST" > "$OUT_A"
adapters/topology-report-v0/emit_topology_report.sh "$SUBJECT" "$INPUT_DIGEST" > "$OUT_B"

cmp -s "$OUT_A" "$OUT_B" || { echo "ERROR: topology report not deterministic" >&2; exit 2; }
grep -Fq '"kind":"topology_report.v0"' "$OUT_A" || { echo "ERROR: missing report kind" >&2; exit 2; }

echo "ok topology-report-v0 golden (scaffold)"
