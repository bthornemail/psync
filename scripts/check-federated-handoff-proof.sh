#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROOF_FILE="$ROOT_DIR/docs/proofs/federated-handoff.latest.md"

test -f "$PROOF_FILE"

grep -Fq 'from_space":"alpha"' "$PROOF_FILE"
grep -Fq 'alpha_has_beta_review=no' "$PROOF_FILE"
grep -Fq 'beta_has_alpha_model=no' "$PROOF_FILE"
grep -Fq 'beta_has_handoff=yes' "$PROOF_FILE"
grep -Fq 'trace --space alpha' "$PROOF_FILE"
grep -Fq 'trace --space beta' "$PROOF_FILE"
grep -Fq '[verify-wire] ok wire conformance' "$PROOF_FILE"

printf 'federated handoff proof receipt anchors: ok\n'
