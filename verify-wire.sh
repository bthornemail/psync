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

log "Cross-checking full body-kind verification in Rust"
FULL_SK="72a136dc318533d167df476ff76d511d471177137263b532d15fd5f4200f6101"
FULL_AUTHOR="1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f"
FULL_TOPIC_FILE="/tmp/fullbody-topic.verify-wire.ndjson"
FULL_IN_A="/tmp/fullbody-a.verify-wire.bin"
FULL_IN_B="/tmp/fullbody-b.verify-wire.bin"
FULL_IN_C="/tmp/fullbody-c.verify-wire.bin"
FULL_DUMMY="1220cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

printf 'fullbody-A\n' > "$FULL_IN_A"
printf 'fullbody-B\n' > "$FULL_IN_B"
printf 'fullbody-C\n' > "$FULL_IN_C"
FULL_A="$("$FTF_BIN" cas-put "$FULL_IN_A")"
FULL_B="$("$FTF_BIN" cas-put "$FULL_IN_B")"
FULL_C="$("$FTF_BIN" cas-put "$FULL_IN_C")"

python3 - <<PY
import json
m1={"v":1,"realm":"ftf","topic":"provenance/fullbody","prev":None,"t":1,"author":"$FULL_AUTHOR","caps":[],"body":{"kind":"put","artifact":{"hash":"$FULL_A"}},"witness":None,"sig":""}
open('/tmp/fullbody-m1.ndjson','w').write(json.dumps(m1,separators=(',',':'))+'\\n')
PY
"$FTF_BIN" sign-msg --sk "$FULL_SK" /tmp/fullbody-m1.ndjson > /tmp/fullbody-m1.signed.ndjson
FULL_MH1="$("$FTF_BIN" hash-msg /tmp/fullbody-m1.ndjson)"

python3 - <<PY
import json
m2={"v":1,"realm":"ftf","topic":"provenance/fullbody","prev":"$FULL_MH1","t":2,"author":"$FULL_AUTHOR","caps":[],"body":{"kind":"use","inputs":["$FULL_A"],"purpose":"fullbody-check"},"witness":None,"sig":""}
open('/tmp/fullbody-m2.ndjson','w').write(json.dumps(m2,separators=(',',':'))+'\\n')
PY
"$FTF_BIN" sign-msg --sk "$FULL_SK" /tmp/fullbody-m2.ndjson > /tmp/fullbody-m2.signed.ndjson
FULL_MH2="$("$FTF_BIN" hash-msg /tmp/fullbody-m2.ndjson)"

python3 - <<PY
import json
m3={"v":1,"realm":"ftf","topic":"provenance/fullbody","prev":"$FULL_MH2","t":3,"author":"$FULL_AUTHOR","caps":[],"body":{"kind":"xform","tool":{"id":"$FULL_DUMMY","version":"v1","params_hash":"$FULL_DUMMY"},"inputs":["$FULL_A"],"outputs":["$FULL_B"],"receipt":{"recipe_hash":"$FULL_DUMMY","env_hash":"$FULL_DUMMY"}},"witness":None,"sig":""}
open('/tmp/fullbody-m3.ndjson','w').write(json.dumps(m3,separators=(',',':'))+'\\n')
PY
"$FTF_BIN" sign-msg --sk "$FULL_SK" /tmp/fullbody-m3.ndjson > /tmp/fullbody-m3.signed.ndjson
FULL_MH3="$("$FTF_BIN" hash-msg /tmp/fullbody-m3.ndjson)"

python3 - <<PY
import json
m4={"v":1,"realm":"ftf","topic":"provenance/fullbody","prev":"$FULL_MH3","t":4,"author":"$FULL_AUTHOR","caps":[],"body":{"kind":"attest","about":"$FULL_MH3","claim":"reproduced","evidence":["$FULL_A","$FULL_C"]},"witness":None,"sig":""}
open('/tmp/fullbody-m4.ndjson','w').write(json.dumps(m4,separators=(',',':'))+'\\n')
PY
"$FTF_BIN" sign-msg --sk "$FULL_SK" /tmp/fullbody-m4.ndjson > /tmp/fullbody-m4.signed.ndjson
FULL_MH4="$("$FTF_BIN" hash-msg /tmp/fullbody-m4.ndjson)"

python3 - <<PY
import json
m5={"v":1,"realm":"ftf","topic":"provenance/fullbody","prev":"$FULL_MH4","t":5,"author":"$FULL_AUTHOR","caps":[],"body":{"kind":"revoke","target":"$FULL_MH3","reason":"fullbody-check","superseded_by":None},"witness":None,"sig":""}
open('/tmp/fullbody-m5.ndjson','w').write(json.dumps(m5,separators=(',',':'))+'\\n')
PY
"$FTF_BIN" sign-msg --sk "$FULL_SK" /tmp/fullbody-m5.ndjson > /tmp/fullbody-m5.signed.ndjson

cat /tmp/fullbody-m1.signed.ndjson \
  /tmp/fullbody-m2.signed.ndjson \
  /tmp/fullbody-m3.signed.ndjson \
  /tmp/fullbody-m4.signed.ndjson \
  /tmp/fullbody-m5.signed.ndjson > "$FULL_TOPIC_FILE"

FULL_VERIFY_OUTPUT="$(cd "$ROOT_DIR/rust/ftf-verify" && cat "$FULL_TOPIC_FILE" | cargo run -- verify-topic ftf provenance/fullbody)"
printf '%s\n' "$FULL_VERIFY_OUTPUT"
if ! grep -q '^verified=5$' <<<"$FULL_VERIFY_OUTPUT"; then
  printf '[verify-wire] expected verified=5 for full body-kind topic\n' >&2
  exit 1
fi
if ! grep -q '^rejected=0$' <<<"$FULL_VERIFY_OUTPUT"; then
  printf '[verify-wire] expected rejected=0 for full body-kind topic\n' >&2
  exit 1
fi

log "Running trace conformance checks in Haskell"
TRACE_SK="72a136dc318533d167df476ff76d511d471177137263b532d15fd5f4200f6101"
TRACE_AUTHOR="1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f"
TRACE_TOPIC_FILE="/tmp/trace-topic.verify-wire.ndjson"
TRACE_OUTPUT="/tmp/trace.verify-wire.out"
TRACE_IN_FILE="/tmp/trace-input.verify-wire.bin"
TRACE_OUT_FILE="/tmp/trace-output.verify-wire.bin"
fail_trace() {
  printf '[verify-wire] trace output follows:\n' >&2
  tail -n 200 "$TRACE_OUTPUT" >&2 || true
  exit 1
}

printf 'trace-wire-input\n' > "$TRACE_IN_FILE"
printf 'trace-wire-output\n' > "$TRACE_OUT_FILE"
TRACE_A="$("$FTF_BIN" cas-put "$TRACE_IN_FILE")"
TRACE_B="$("$FTF_BIN" cas-put "$TRACE_OUT_FILE")"
TRACE_DUMMY="1220bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

python3 - <<PY
import json
m1={"v":1,"realm":"ftf","topic":"provenance/demo","prev":None,"t":1,"author":"$TRACE_AUTHOR","caps":[],"body":{"kind":"put","artifact":{"hash":"$TRACE_A"}},"witness":None,"sig":""}
open('/tmp/trace-m1.ndjson','w').write(json.dumps(m1,separators=(',',':'))+'\\n')
PY
"$FTF_BIN" sign-msg --sk "$TRACE_SK" /tmp/trace-m1.ndjson > /tmp/trace-m1.signed.ndjson
TRACE_MH1="$("$FTF_BIN" hash-msg /tmp/trace-m1.ndjson)"

python3 - <<PY
import json
u={"v":1,"realm":"ftf","topic":"provenance/demo","prev":None,"t":0,"author":"$TRACE_AUTHOR","caps":[],"body":{"kind":"put","artifact":{"hash":"$TRACE_DUMMY"}},"witness":None,"sig":""}
open('/tmp/trace-u.ndjson','w').write(json.dumps(u,separators=(',',':'))+'\\n')
PY
TRACE_U="$("$FTF_BIN" hash-msg /tmp/trace-u.ndjson)"

python3 - <<PY
import json
m2={"v":1,"realm":"ftf","topic":"provenance/demo","prev":"$TRACE_MH1","t":2,"author":"$TRACE_AUTHOR","caps":[],"body":{"kind":"xform","tool":{"id":"$TRACE_DUMMY","version":"v1","params_hash":"$TRACE_DUMMY"},"inputs":["$TRACE_A","$TRACE_U"],"outputs":["$TRACE_B"],"receipt":{"recipe_hash":"$TRACE_DUMMY","env_hash":"$TRACE_DUMMY"}},"witness":None,"sig":""}
open('/tmp/trace-m2.ndjson','w').write(json.dumps(m2,separators=(',',':'))+'\\n')
PY
"$FTF_BIN" sign-msg --sk "$TRACE_SK" /tmp/trace-m2.ndjson > /tmp/trace-m2.signed.ndjson

cat /tmp/trace-m1.signed.ndjson /tmp/trace-m2.signed.ndjson > "$TRACE_TOPIC_FILE"
"$FTF_BIN" trace --realm ftf --topic provenance/demo "$TRACE_B" "$TRACE_TOPIC_FILE" > "$TRACE_OUTPUT"

if ! grep "\"kind\":\"trace.header\"" "$TRACE_OUTPUT" | grep "\"root\":\"$TRACE_B\"" >/dev/null; then
  printf '[verify-wire] trace header root mismatch\n' >&2
  fail_trace
fi
if ! grep "\"kind\":\"trace.artifact\"" "$TRACE_OUTPUT" | grep "\"h\":\"$TRACE_B\"" | grep "\"status\":\"ok\"" >/dev/null; then
  printf '[verify-wire] trace root artifact should be materialized (status=ok)\n' >&2
  fail_trace
fi
if ! grep -q "\"kind\":\"trace.event\"" "$TRACE_OUTPUT"; then
  printf '[verify-wire] trace missing event records\n' >&2
  fail_trace
fi
if ! grep -q "\"etype\":\"xform\"" "$TRACE_OUTPUT"; then
  printf '[verify-wire] trace missing xform event\n' >&2
  fail_trace
fi
if ! grep -q "\"outputs\":\\[\"$TRACE_B\"" "$TRACE_OUTPUT"; then
  printf '[verify-wire] trace missing xform output for root\n' >&2
  fail_trace
fi
if ! grep "\"kind\":\"trace.edge\"" "$TRACE_OUTPUT" | grep "\"rel\":\"produces\"" | grep "\"to\":\"artifact:$TRACE_B\"" >/dev/null; then
  printf '[verify-wire] trace missing produces edge to root artifact\n' >&2
  fail_trace
fi
if ! grep -q "\"h\":\"$TRACE_A\"" "$TRACE_OUTPUT"; then
  printf '[verify-wire] trace missing dependency artifact record\n' >&2
  fail_trace
fi
if ! grep "\"kind\":\"trace.artifact\"" "$TRACE_OUTPUT" | grep "\"h\":\"$TRACE_A\"" | grep "\"status\":\"ok\"" >/dev/null; then
  printf '[verify-wire] trace expected materialized dependency TRACE_A to be status=ok\n' >&2
  fail_trace
fi
if ! grep "\"kind\":\"trace.artifact\"" "$TRACE_OUTPUT" | grep "\"h\":\"$TRACE_U\"" | grep "\"status\":\"pending_fetch\"" >/dev/null; then
  printf '[verify-wire] trace expected unmaterialized dependency TRACE_U to be status=pending_fetch\n' >&2
  fail_trace
fi

log "ok wire conformance"
