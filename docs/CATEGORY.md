# Category View of FTF

This note gives a compact mathematical interpretation of the FTF protocol.

## Core Mapping

- Objects: artifact hashes (CAS identities).
- Morphisms: verified `xform` events.
- Composition: provenance path composition recovered by deterministic replay.
- Identity/object introduction: `put` (operational witness that an object is present in the verified world).

In shorthand:

- `f : A -> B` means an `xform` that consumes `A` and produces `B`.
- `f : A x U -> B` means a multi-input `xform(inputs=[A,U], outputs=[B])`.

## Free Category Intuition

Let:

- `Ob` be artifact hashes.
- `Gen` be verified `xform` events.

Each generator `g in Gen` has a typed boundary:

- `src(g)` = input artifact tuple.
- `tgt(g)` = output artifact tuple.

Replay over verified messages generates composable paths, yielding a free
category-like provenance structure over these generators.

## Deterministic Recovery

Replay order is deterministic:

- key = `(t, mh_bytes)` ascending.

This does not define composition itself; it defines a stable procedure for
recovering the same compositional structure from append-only logs.

`trace` is the query surface that materializes this recovered structure as
deterministic NDJSON (`trace.header`, `trace.artifact`, `trace.event`,
`trace.note`, `trace.edge`).

## Notes Are Annotations, Not Morphisms

`attest` and `revoke` are statements about objects/morphisms, not structural
transformations.

- `attest(about=...)` is positive evidence.
- `revoke(target=...)` is negative evidence.

Therefore they appear as `trace.note` and do not delete or rewrite lineage.

## Alias Is A Separate Name Layer

Canonical identity is artifact hash; alias is an external name mapping layer.

- `alias : Name -> Object`

Keeping alias resolution separate from base provenance structure preserves
determinism and fail-closed semantics.

## Layered Model

- Base layer: artifacts + transforms (`put/use/xform`).
- Evidence layer: annotations (`attest/revoke` and witness-oriented claims).
- Name layer: logical IDs over canonical objects (`alias_claim` replay).
- Replay/query layer: deterministic reconstruction and trace emission.

This separation is why FTF behaves like a stable protocol surface rather than
an ad hoc log format.
