#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROOF_FILE="$ROOT_DIR/docs/proofs/spaces-must-reject.latest.md"

test -f "$PROOF_FILE"

grep -Fq 'does/not/exist' "$PROOF_FILE"
grep -Fq 'invalid encoding at offset: 0' "$PROOF_FILE"
grep -Fq 'target not found in verified space/topic' "$PROOF_FILE"
grep -Fq 'topic has rejected messages: provenance/main' "$PROOF_FILE"
grep -Fq 'lines_before=1' "$PROOF_FILE"
grep -Fq 'lines_after=1' "$PROOF_FILE"
grep -Fq '[verify-wire] ok wire conformance' "$PROOF_FILE"

printf 'spaces must-reject proof receipt anchors: ok\n'
