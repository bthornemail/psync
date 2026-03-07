#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC_PROOF="$ROOT_DIR/public/docs/proofs/federated-handoff.latest.md"
MANIFEST="$ROOT_DIR/public/docs/observatory-manifest.json"

test -f "$PUBLIC_PROOF"
grep -Fq 'federated-handoff.latest.md' "$MANIFEST"
grep -Fq 'alpha_has_beta_review=no' "$PUBLIC_PROOF"
grep -Fq 'beta_has_alpha_model=no' "$PUBLIC_PROOF"
grep -Fq '[verify-wire] ok wire conformance' "$PUBLIC_PROOF"

printf 'public federated handoff proof publication anchors: ok\n'
