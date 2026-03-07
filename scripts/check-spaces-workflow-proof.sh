#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROOF_FILE="$ROOT_DIR/docs/proofs/spaces-workflow.latest.md"

test -f "$PROOF_FILE"

grep -Eq 'event:[[:space:]]+1220[0-9a-f]{64}' "$PROOF_FILE"
grep -Fq 'trace.note' "$PROOF_FILE"
grep -Fq '"note_type":"attest"' "$PROOF_FILE"
grep -Fq '"note_type":"revoke"' "$PROOF_FILE"
grep -Fq '[verify-wire] ok wire conformance' "$PROOF_FILE"
grep -Fq 'xform' "$PROOF_FILE"
grep -Fq 'attest' "$PROOF_FILE"
grep -Fq 'revoke' "$PROOF_FILE"

printf 'spaces workflow proof receipt anchors: ok\n'
