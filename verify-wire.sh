#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FTF_BIN=""
SIGNED_TMP="/tmp/alias-claim-1.signed.ndjson"

log() {
  printf '[verify-wire] %s\n' "$*"
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf '[verify-wire] missing required file: %s\n' "$path" >&2
    exit 1
  fi
}

require_file "$ROOT_DIR/test/vectors/alias-claim-1.ndjson"
require_file "$ROOT_DIR/test/vectors/alias-claim-1.mh"
require_file "$ROOT_DIR/test/vectors/alias-claim-1.sig"

log "Building Haskell CLI"
(
  cd "$ROOT_DIR"
  cabal build --builddir=.cabal-ftf
)

log "Running Haskell selftest"
(
  cd "$ROOT_DIR"
  FTF_BIN="$(cabal list-bin --builddir=.cabal-ftf ftf)"
  "$FTF_BIN" selftest
)

log "Building Rust verifier"
(
  cd "$ROOT_DIR/rust/ftf-verify"
  cargo build
)

log "Generating signed alias fixture from Haskell sign-msg"
FTF_BIN="$(cd "$ROOT_DIR" && cabal list-bin --builddir=.cabal-ftf ftf)"
"$FTF_BIN" sign-msg \
  --sk 72a136dc318533d167df476ff76d511d471177137263b532d15fd5f4200f6101 \
  "$ROOT_DIR/test/vectors/alias-claim-1.ndjson" > "$SIGNED_TMP"

log "Cross-checking verify-topic in Rust"
VERIFY_OUTPUT="$(cd "$ROOT_DIR/rust/ftf-verify" && cat "$SIGNED_TMP" | cargo run -- verify-topic ftf alias/main)"
printf '%s\n' "$VERIFY_OUTPUT"
if ! grep -q '^verified=1$' <<<"$VERIFY_OUTPUT"; then
  printf '[verify-wire] expected verified=1\n' >&2
  exit 1
fi
if ! grep -q '^rejected=0$' <<<"$VERIFY_OUTPUT"; then
  printf '[verify-wire] expected rejected=0\n' >&2
  exit 1
fi

log "Cross-checking resolve-alias in Rust"
RESOLVE_OUTPUT="$(cd "$ROOT_DIR/rust/ftf-verify" && cat "$SIGNED_TMP" | cargo run -- resolve-alias ftf alias/main WORLD:alpha)"
printf '%s\n' "$RESOLVE_OUTPUT"
if ! grep -q '^quarantine=0$' <<<"$RESOLVE_OUTPUT"; then
  printf '[verify-wire] expected quarantine=0\n' >&2
  exit 1
fi
if ! grep -q '^target_hash=12200000000000000000000000000000000000000000000000000000000000000000$' <<<"$RESOLVE_OUTPUT"; then
  printf '[verify-wire] expected target_hash for WORLD:alpha\n' >&2
  exit 1
fi

log "ok wire conformance"
