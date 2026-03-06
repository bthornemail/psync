#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$ROOT_DIR"
cabal build --builddir=.cabal-ftf >/dev/null
FTF_BIN="$(cabal list-bin --builddir=.cabal-ftf ftf)"

cd "$TMP_DIR"
OUTPUT="$("$FTF_BIN" space new lab --show-seed)"
printf '%s\n' "$OUTPUT"

grep -q '^Space: lab$' <<<"$OUTPUT"
grep -q '^Realm: ftf:lab$' <<<"$OUTPUT"
grep -q '^Space ID: 1220' <<<"$OUTPUT"
grep -q '^Created: .ftf/spaces/lab$' <<<"$OUTPUT"
grep -q '^Seed: ' <<<"$OUTPUT"

test -d .ftf/spaces/lab/topics
test -d .ftf/spaces/lab/cas
test -d .ftf/spaces/lab/keys
test -f .ftf/spaces/lab/space.json
test -f .ftf/spaces/lab/keys/owner.json
test -f .ftf/config.json

grep -q '"name":"lab"' .ftf/spaces/lab/space.json
grep -q '"realm":"ftf:lab"' .ftf/spaces/lab/space.json
grep -q '"default_topic":"provenance/main"' .ftf/spaces/lab/space.json
grep -q '"active_member":"owner"' .ftf/spaces/lab/space.json
grep -q '"active_space":"lab"' .ftf/config.json

SHOW_OUTPUT="$("$FTF_BIN" space show lab)"
printf '%s\n' "$SHOW_OUTPUT"

grep -q '^Space: lab$' <<<"$SHOW_OUTPUT"
grep -q '^Realm: ftf:lab$' <<<"$SHOW_OUTPUT"
grep -q '^Space ID: 1220' <<<"$SHOW_OUTPUT"
grep -q '^Members: 1$' <<<"$SHOW_OUTPUT"
grep -q '^Topics: 0$' <<<"$SHOW_OUTPUT"
grep -q '^CAS Objects: 0$' <<<"$SHOW_OUTPUT"
grep -q '^Active Member: owner$' <<<"$SHOW_OUTPUT"

LIST_OUTPUT="$("$FTF_BIN" space ls)"
printf '%s\n' "$LIST_OUTPUT"

grep -q $'^lab\trealm=ftf:lab\tmembers=1$' <<<"$LIST_OUTPUT"

DERIVE_OUTPUT_1="$("$FTF_BIN" identity derive --space lab --role auditor)"
printf '%s\n' "$DERIVE_OUTPUT_1"

DERIVE_OUTPUT_2="$("$FTF_BIN" identity derive --space lab --role auditor)"
printf '%s\n' "$DERIVE_OUTPUT_2"

AUDITOR_PK_1="$(sed -n 's/^Public Key: //p' <<<"$DERIVE_OUTPUT_1")"
AUDITOR_PK_2="$(sed -n 's/^Public Key: //p' <<<"$DERIVE_OUTPUT_2")"

grep -q '^Member: auditor$' <<<"$DERIVE_OUTPUT_1"
grep -q '^Path: m/2$' <<<"$DERIVE_OUTPUT_1"
grep -q '^Public Key: ' <<<"$DERIVE_OUTPUT_1"
grep -q '^Peer ID: ' <<<"$DERIVE_OUTPUT_1"
grep -q '^Stored: .ftf/spaces/lab/keys/auditor.json$' <<<"$DERIVE_OUTPUT_1"
test -n "$AUDITOR_PK_1"
test "$AUDITOR_PK_1" = "$AUDITOR_PK_2"
test -f .ftf/spaces/lab/keys/auditor.json

IDENTITY_SHOW_OWNER="$("$FTF_BIN" identity show --space lab)"
printf '%s\n' "$IDENTITY_SHOW_OWNER"

grep -q '^Space: lab$' <<<"$IDENTITY_SHOW_OWNER"
grep -q '^Active Member: owner$' <<<"$IDENTITY_SHOW_OWNER"

IDENTITY_USE_OUTPUT="$("$FTF_BIN" identity use --space lab --member auditor)"
printf '%s\n' "$IDENTITY_USE_OUTPUT"

grep -q '^Space: lab$' <<<"$IDENTITY_USE_OUTPUT"
grep -q '^Active Member: auditor$' <<<"$IDENTITY_USE_OUTPUT"
grep -q '"active_member":"auditor"' .ftf/spaces/lab/space.json

IDENTITY_SHOW_AUDITOR="$("$FTF_BIN" identity show --space lab)"
printf '%s\n' "$IDENTITY_SHOW_AUDITOR"

grep -q '^Active Member: auditor$' <<<"$IDENTITY_SHOW_AUDITOR"
grep -q "^Public Key: $AUDITOR_PK_1$" <<<"$IDENTITY_SHOW_AUDITOR"

SHOW_OUTPUT_AFTER_DERIVE="$("$FTF_BIN" space show lab)"
printf '%s\n' "$SHOW_OUTPUT_AFTER_DERIVE"

grep -q '^Members: 2$' <<<"$SHOW_OUTPUT_AFTER_DERIVE"

printf 'space-test-payload\n' > artifact.bin
PUT_OUTPUT="$("$FTF_BIN" put artifact.bin --space lab)"
printf '%s\n' "$PUT_OUTPUT"

ARTIFACT_HASH="$(sed -n 's/^artifact: //p' <<<"$PUT_OUTPUT")"
EVENT_HASH="$(sed -n 's/^event:    //p' <<<"$PUT_OUTPUT")"

grep -q '^artifact: 1220' <<<"$PUT_OUTPUT"
grep -q '^event:    1220' <<<"$PUT_OUTPUT"
grep -q '^topic:    provenance/main$' <<<"$PUT_OUTPUT"
test -n "$ARTIFACT_HASH"
test -n "$EVENT_HASH"
test -f .ftf/spaces/lab/topics/provenance/main.ndjson
grep -q "\"hash\":\"$ARTIFACT_HASH\"" .ftf/spaces/lab/topics/provenance/main.ndjson
grep -q "\"author\":\"$AUDITOR_PK_1\"" .ftf/spaces/lab/topics/provenance/main.ndjson

TRACE_OUTPUT="$("$FTF_BIN" trace --space lab "$ARTIFACT_HASH")"
printf '%s\n' "$TRACE_OUTPUT"

grep -q "\"kind\":\"trace.header\"" <<<"$TRACE_OUTPUT"
grep -q "\"root\":\"$ARTIFACT_HASH\"" <<<"$TRACE_OUTPUT"
grep -q "\"kind\":\"trace.event\"" <<<"$TRACE_OUTPUT"
grep -q "\"etype\":\"put\"" <<<"$TRACE_OUTPUT"
grep -q "\"mh\":\"$EVENT_HASH\"" <<<"$TRACE_OUTPUT"
grep -q "\"kind\":\"trace.artifact\"" <<<"$TRACE_OUTPUT"
grep -q "\"h\":\"$ARTIFACT_HASH\"" <<<"$TRACE_OUTPUT"
grep -q "\"status\":\"ok\"" <<<"$TRACE_OUTPUT"

TRACE_OUTPUT_ACTIVE="$("$FTF_BIN" trace "$ARTIFACT_HASH")"
printf '%s\n' "$TRACE_OUTPUT_ACTIVE"

grep -q "\"root\":\"$ARTIFACT_HASH\"" <<<"$TRACE_OUTPUT_ACTIVE"

printf 'space-model-output\n' > model.bin
XFORM_OUTPUT="$("$FTF_BIN" xform train-model --space lab --input artifact.bin --output model.bin)"
printf '%s\n' "$XFORM_OUTPUT"

MODEL_HASH="$(sed -n 's/^output:   //p' <<<"$XFORM_OUTPUT")"
XFORM_EVENT_HASH="$(sed -n 's/^event:    //p' <<<"$XFORM_OUTPUT")"

grep -q '^event:    1220' <<<"$XFORM_OUTPUT"
grep -q '^topic:    provenance/main$' <<<"$XFORM_OUTPUT"
grep -q '^output:   1220' <<<"$XFORM_OUTPUT"
test -n "$MODEL_HASH"
test -n "$XFORM_EVENT_HASH"
grep -q "\"author\":\"$AUDITOR_PK_1\"" .ftf/spaces/lab/topics/provenance/main.ndjson

TRACE_MODEL_OUTPUT="$("$FTF_BIN" trace --space lab "$MODEL_HASH")"
printf '%s\n' "$TRACE_MODEL_OUTPUT"

grep -q "\"root\":\"$MODEL_HASH\"" <<<"$TRACE_MODEL_OUTPUT"
grep -q "\"etype\":\"xform\"" <<<"$TRACE_MODEL_OUTPUT"
grep -q "\"mh\":\"$XFORM_EVENT_HASH\"" <<<"$TRACE_MODEL_OUTPUT"
grep -q "\"h\":\"$ARTIFACT_HASH\"" <<<"$TRACE_MODEL_OUTPUT"
grep -q "\"h\":\"$MODEL_HASH\"" <<<"$TRACE_MODEL_OUTPUT"
grep -q "\"rel\":\"consumed_by\"" <<<"$TRACE_MODEL_OUTPUT"
grep -q "\"rel\":\"produces\"" <<<"$TRACE_MODEL_OUTPUT"

ALIAS_SET_OUTPUT="$("$FTF_BIN" alias set model/latest "$MODEL_HASH" --space lab)"
printf '%s\n' "$ALIAS_SET_OUTPUT"

ALIAS_EVENT_HASH="$(sed -n 's/^event:   //p' <<<"$ALIAS_SET_OUTPUT")"

grep -q '^id:      model/latest$' <<<"$ALIAS_SET_OUTPUT"
grep -q "^target:  $MODEL_HASH$" <<<"$ALIAS_SET_OUTPUT"
grep -q '^event:   1220' <<<"$ALIAS_SET_OUTPUT"
grep -q '^topic:   alias/main$' <<<"$ALIAS_SET_OUTPUT"
test -n "$ALIAS_EVENT_HASH"
test -f .ftf/spaces/lab/topics/alias/main.ndjson
grep -q "\"target_hash\":\"$MODEL_HASH\"" .ftf/spaces/lab/topics/alias/main.ndjson
grep -q "\"author\":\"$AUDITOR_PK_1\"" .ftf/spaces/lab/topics/alias/main.ndjson

ALIAS_GET_OUTPUT="$("$FTF_BIN" alias get model/latest --space lab)"
printf '%s\n' "$ALIAS_GET_OUTPUT"

grep -q '^quarantine=0$' <<<"$ALIAS_GET_OUTPUT"
grep -q "^target_hash=$MODEL_HASH$" <<<"$ALIAS_GET_OUTPUT"
grep -q '^status=ok$' <<<"$ALIAS_GET_OUTPUT"

ALIAS_LIST_OUTPUT="$("$FTF_BIN" alias ls --space lab)"
printf '%s\n' "$ALIAS_LIST_OUTPUT"

grep -q '^quarantine=0$' <<<"$ALIAS_LIST_OUTPUT"
grep -q "^model/latest"$'\t'"target=$MODEL_HASH"$'\t'"status=ok$" <<<"$ALIAS_LIST_OUTPUT"

TRACE_OUTPUT_ALIAS="$("$FTF_BIN" trace --space lab model/latest)"
printf '%s\n' "$TRACE_OUTPUT_ALIAS"

grep -q "\"root\":\"$MODEL_HASH\"" <<<"$TRACE_OUTPUT_ALIAS"

TRACE_OUTPUT_PATH="$("$FTF_BIN" trace --space lab model.bin)"
printf '%s\n' "$TRACE_OUTPUT_PATH"

grep -q "\"root\":\"$MODEL_HASH\"" <<<"$TRACE_OUTPUT_PATH"
