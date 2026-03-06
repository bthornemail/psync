# Proof Receipts Index

This directory contains bounded, reproducible proof receipts for protocol and query semantics.

Related model note: [CATEGORY.md](/root/psync/docs/CATEGORY.md)

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

### Full Body Rust Conformance

- Establishes: Rust verifier parity for full body-kind wire projection (`put/use/xform/attest/revoke`) against Haskell-signed stream.
- Command: `bash verify-wire.sh` (full-body segment: `verify-topic ftf provenance/fullbody`)
- Latest: [fullbody-rust-conformance.latest.md](/root/psync/docs/proofs/fullbody-rust-conformance.latest.md)

### Spaces Workflow

- Establishes: bounded space-local workflow semantics for `put`, `xform`, `attest`, `revoke`, `alias`, and `trace` under active-member signing.
- Command: `bash scripts/smoke-space-new.sh`
- Latest: [spaces-workflow.latest.md](/root/psync/docs/proofs/spaces-workflow.latest.md)

### Spaces Must-Reject

- Establishes: fail-closed behavior for space-local wrappers under unresolved targets, malformed evidence, unreachable revoke targets, and rejected topic replay state.
- Command: bounded local must-reject scenario plus baseline `bash verify-wire.sh`
- Latest: [spaces-must-reject.latest.md](/root/psync/docs/proofs/spaces-must-reject.latest.md)

### Federated Handoff

- Establishes: locality by default across spaces, with explicit interoperability only through a handoff artifact and no implicit global merge.
- Command: bounded two-space local handoff scenario plus baseline `bash verify-wire.sh`
- Latest: [federated-handoff.latest.md](/root/psync/docs/proofs/federated-handoff.latest.md)

### Federated Must-Reject

- Establishes: fail-closed federation boundary under no-reference-without-receipt, no-import-without-valid-receipt, and no-authority-without-local-grant.
- Command: bounded negative two-space scenario plus baseline `bash verify-wire.sh`
- Latest: [federated-must-reject.latest.md](/root/psync/docs/proofs/federated-must-reject.latest.md)
