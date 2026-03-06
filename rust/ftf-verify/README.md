# ftf-verify (Rust)

Minimal cross-language conformance verifier for the FTF frozen wire format.

This tool validates that an implementation produces the same message hash (`mh`), signature verification, and deterministic replay results as the reference Haskell implementation.

It is intended as a protocol test harness, not a full node.

## What it verifies

For each NDJSON message stream:

1. Transport parsing
- NDJSON input (one JSON message per line)

2. Canonical projection
- Deterministic CBOR arrays
- Fixed positional fields
- Explicit `null` for optionals

3. Hash construction

```text
mh = multihash(
       sha2-256(
         "ftf-msg-v1\0" || cbor(blankSig(msg))
       )
     )
```

4. Signature verification

```text
Ed25519.Verify(author_public_key, mh_bytes, sig)
```

Signature payload is raw multihash bytes.

5. Verified view gates
- K2: signature correctness
- K3: append-only linkage
- K4: monotone causal clock

6. Deterministic replay

```text
(t, mh_bytes)
```

Where `mh_bytes` are compared lexicographically.

7. Alias resolution
- Alias topics enforce strict head-linking: `prev_alias_hash == current_head`
- Otherwise: `quarantine(message)`

## Repository layout

```text
repo-root/
  rust/ftf-verify/
  test/vectors/
      alias-claim-1.ndjson
      alias-claim-1.mh
      alias-claim-1.sig
      alias-claim-1.signed.ndjson
```

The signed fixture is produced via `ftf sign-msg` from the Haskell reference CLI.

## Build

From repository root:

```bash
cd rust/ftf-verify
cargo build
```

## Verify Topic

```bash
cat ../../test/vectors/alias-claim-1.signed.ndjson \
  | cargo run -- verify-topic ftf alias/main
```

Expected output:

```text
verified=1
OK 12203f946b72... t=1
rejected=0
```

## Resolve Alias

```bash
cat ../../test/vectors/alias-claim-1.signed.ndjson \
  | cargo run -- resolve-alias ftf alias/main WORLD:alpha
```

Expected output:

```text
quarantine=0
target_hash=12200000000000000000000000000000000000000000000000000000000000000000
```

## Purpose

This verifier proves that the following protocol invariants are cross-language reproducible:

- deterministic CBOR projection
- domain-separated hashing
- multihash encoding
- Ed25519 signature semantics
- deterministic replay ordering
- fail-closed alias resolution

If another language implementation produces the same results, it is wire-compatible with FTF.

## Future extensions

Planned additions:

- CBOR projection support for:
  - `put`
  - `use`
  - `xform`
  - `attest`
  - `revoke`
- disk-backed CAS validation
- provenance replay verification

## Why this exists

This tool guarantees that FTF provenance chains remain deterministic across implementations, enabling:

- offline-first federation
- reproducible audit trails
- tamper-evident provenance without global consensus
