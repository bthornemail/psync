#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC_PROOF="$ROOT_DIR/public/docs/proofs/federated-must-reject.latest.md"
MANIFEST="$ROOT_DIR/public/docs/observatory-manifest.json"

test -f "$PUBLIC_PROOF"
grep -Fq 'federated-must-reject.latest.md' "$MANIFEST"
grep -Fq 'input artifact not found in local space' "$PUBLIC_PROOF"
grep -Fq 'bad_trace_has_alpha_model=no' "$PUBLIC_PROOF"
grep -Fq '[verify-wire] ok wire conformance' "$PUBLIC_PROOF"

printf 'public federated must-reject proof publication anchors: ok\n'
