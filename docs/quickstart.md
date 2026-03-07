# Quickstart

This quickstart uses the local `ftf` CLI and NDJSON message files.

## 1. Build CLI

```bash
cabal build --builddir=.cabal-ftf
FTF_BIN="$(cabal list-bin --builddir=.cabal-ftf ftf)"
```

## 2. Put Artifact In CAS

```bash
printf 'hello-ftf\n' > /tmp/hello.bin
ART_HASH="$($FTF_BIN cas-put /tmp/hello.bin)"
echo "$ART_HASH"
```

## 3. Create And Sign A Message

Create one `put` message line in NDJSON:

```bash
cat > /tmp/m1.ndjson <<'JSON'
{"v":1,"realm":"ftf","topic":"demo/topic","prev":null,"t":1,"author":"<AUTHOR_PK_HEX>","caps":[],"body":{"kind":"put","artifact":{"hash":"<ART_HASH>"}},"witness":null,"sig":""}
JSON
```

Sign it:

```bash
$FTF_BIN sign-msg --sk <SECRET_KEY_HEX> /tmp/m1.ndjson > /tmp/m1.signed.ndjson
```

## 4. Verify Topic

```bash
$FTF_BIN verify-topic --realm ftf --topic demo/topic /tmp/m1.signed.ndjson
```

## 5. Trace Lineage

```bash
$FTF_BIN trace --realm ftf --topic demo/topic <ROOT_ARTIFACT_MH_HEX> /tmp/m1.signed.ndjson
```

## 6. Run Full Conformance Harness

```bash
bash verify-wire.sh
```

Expected success marker:

```text
[verify-wire] ok wire conformance
```
