#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC_PROOF="$ROOT_DIR/public/docs/proofs/spaces-must-reject.latest.md"
MANIFEST="$ROOT_DIR/public/docs/observatory-manifest.json"

test -f "$PUBLIC_PROOF"
grep -Fq 'spaces-must-reject.latest.md' "$MANIFEST"
grep -Fq 'topic has rejected messages: provenance/main' "$PUBLIC_PROOF"
grep -Fq '[verify-wire] ok wire conformance' "$PUBLIC_PROOF"

printf 'public spaces must-reject proof publication anchors: ok\n'
