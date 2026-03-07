# FTF Protocol (v0 Reference)

This document freezes the current wire and replay semantics for the FTF v0
reference implementation.

## Versioning

- Protocol version: `1`
- Message domain tag: `ftf-msg-v1`
- Message preimage prefix: `"ftf-msg-v1\0"`

## Message Wire Model

All messages are canonical CBOR projections of a 10-field record:

1. `v` (int)
2. `realm` (text)
3. `topic` (text)
4. `prev` (hash or null)
5. `t` (integer timestamp / logical time)
6. `author` (ed25519 public key bytes)
7. `caps` (list of text)
8. `body` (tagged body payload)
9. `witness` (hash or null)
10. `sig` (bytes)

### Hash Preimage

For message hash computation, `sig` is blanked before encoding:

`preimage = "ftf-msg-v1\0" || cbor(blankSig(msg))`

Then:

`mh = multihash(sha2-256(preimage))`

Wire representation uses multihash code `0x12` and digest size `32`.

### Signatures

Signatures are Ed25519 over raw multihash bytes:

`sig = Ed25519.Sign(sk, mh_bytes)`

Verification is fail-closed:

- author public key must match signing key/public key
- signature must validate against `mh_bytes`

## Replay Ordering

Deterministic replay ordering is:

`(t, mh_bytes)` ascending

This ordering is used for topic verification and alias replay/resolve behavior.

## Body Kinds

Current body tags:

- `put`
- `use`
- `xform`
- `attest`
- `revoke`
- `alias_claim`

These tags are part of the frozen v0 surface for verification/parsing.

## Trace Semantics

Trace emits deterministic NDJSON with these record kinds:

- `trace.header`
- `trace.artifact`
- `trace.event`
- `trace.note`
- `trace.edge`

Artifact status is derived from local CAS truth:

- `status:"ok"` when blob exists in local CAS
- `status:"pending_fetch"` when blob is not present

`attest` and `revoke` are emitted as annotations (`trace.note`) and do not
mutate historical lineage edges/events.

## Canonical Receipts

See proof receipts in `docs/proofs/`:

- `wire-conformance.latest.md`
- `trace-semantics.latest.md`
- `revoke-semantics.latest.md`
- `attest-semantics.latest.md`

## Mathematical Interpretation

For the categorical model of artifacts, transforms, annotations, and replay,
see [CATEGORY.md](/root/psync/docs/CATEGORY.md).
