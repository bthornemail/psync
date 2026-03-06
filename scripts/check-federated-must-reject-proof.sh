#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROOF_FILE="$ROOT_DIR/docs/proofs/federated-must-reject.latest.md"

test -f "$PROOF_FILE"

grep -Fq 'input artifact not found in local space' "$PROOF_FILE"
grep -Fq 'target not found in verified space/topic' "$PROOF_FILE"
grep -Fq 'lines_before=1' "$PROOF_FILE"
grep -Fq 'lines_after=1' "$PROOF_FILE"
grep -Fq 'bad_trace_has_alpha_model=no' "$PROOF_FILE"
grep -Fq '[verify-wire] ok wire conformance' "$PROOF_FILE"

printf 'federated must-reject proof receipt anchors: ok\n'
