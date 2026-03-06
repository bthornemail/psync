# Proof Receipts Index

This directory contains bounded, reproducible proof receipts for protocol and query semantics.

## Receipts

### Wire Conformance

- Establishes: machine-independent wire behavior and Haskell↔Rust conformance (`hash-msg`, `sign-msg`, `verify-topic`, `resolve-alias`, trace checks).
- Command: `bash verify-wire.sh`
- Latest: [wire-conformance.latest.md](/root/psync/docs/proofs/wire-conformance.latest.md)

### Trace Semantics

- Establishes: bounded materialization semantics for dependencies in trace (`ok` vs `pending_fetch`) under fixed signed input.
- Command: bounded `ftf trace --realm ftf --topic provenance/demo "$B" "$TRACE_TOPIC_FILE"` scenario with `put(A)` and `xform(A,U -> B)`.
- Latest: [trace-semantics.latest.md](/root/psync/docs/proofs/trace-semantics.latest.md)

### Revoke Semantics

- Establishes: revoke is emitted as annotation (`trace.note`), not deletion; lineage remains intact.
- Command: bounded `ftf trace --realm ftf --topic provenance/revoke-demo "$B" "$TRACE_TOPIC_FILE"` scenario with `put(A)`, `xform(A -> B)`, `revoke(target=MH2, ...)`.
- Latest: [revoke-semantics.latest.md](/root/psync/docs/proofs/revoke-semantics.latest.md)

### Attest Semantics

- Establishes: attest is emitted as positive annotation (`trace.note` with claim), not structural mutation.
- Command: bounded `ftf trace --realm ftf --topic provenance/attest-demo "$B" "$TRACE_TOPIC_FILE"` scenario with `put(A)`, `xform(A -> B)`, `attest(about=MH2, claim=...)`.
- Latest: [attest-semantics.latest.md](/root/psync/docs/proofs/attest-semantics.latest.md)
