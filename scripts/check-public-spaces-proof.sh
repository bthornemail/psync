#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC_PROOF="$ROOT_DIR/public/docs/proofs/spaces-workflow.latest.md"
MANIFEST="$ROOT_DIR/public/docs/observatory-manifest.json"

test -f "$PUBLIC_PROOF"
grep -Fq 'spaces-workflow.latest.md' "$MANIFEST"
grep -Fq 'trace.note' "$PUBLIC_PROOF"
grep -Fq '[verify-wire] ok wire conformance' "$PUBLIC_PROOF"

printf 'public spaces proof publication anchors: ok\n'
