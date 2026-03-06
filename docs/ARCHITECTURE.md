# Architecture

FTF is an append-only provenance protocol with deterministic replay and trace
query semantics.

## Dataflow

```text
messages (NDJSON, signed)
  -> hash/sign verify
  -> replay (deterministic order: t, mh)
  -> verified view
      -> alias resolution
      -> lineage graph index
          -> trace query (header/artifact/event/note/edge)
```

## Core Components

- Wire model: canonical CBOR projection, multihash sha2-256, Ed25519 over raw
  multihash bytes.
- Replay engine: fail-closed verification and deterministic ordering.
- CAS layer: local materialization truth (`ok` vs `pending_fetch`).
- Query layer: deterministic trace emission over verified topic history.

## Message Bodies

- `put`: introduce artifact hash
- `use`: consume input artifacts for purpose
- `xform`: transformation from inputs to outputs via tool metadata
- `attest`: positive evidence annotation about event/artifact
- `revoke`: negative evidence annotation about event/artifact
- `alias_claim`: logical id resolution surface

## Invariants

- Verification is fail-closed.
- Replay order is deterministic and stable under map iteration changes.
- Trace output is deterministic and robust to non-semantic JSON differences.
- Notes (`attest`, `revoke`) annotate; they do not rewrite lineage.

## Reference Proof Surface

See `docs/proofs/README.md` for bounded conformance and semantics receipts.

## Mathematical Model

See [CATEGORY.md](/root/psync/docs/CATEGORY.md) for the categorical
interpretation of artifacts, transforms, annotations, and replay.

Companion architecture notes:

- [ARCHITECTURE-BUNDLE.md](/root/psync/docs/ARCHITECTURE-BUNDLE.md)
- [FANO-CLOSURE.md](/root/psync/docs/FANO-CLOSURE.md)
