# Bundle Architecture View

This note explains FTF using a layered bundle-style intuition.

Important: this is a conceptual model for understanding system structure.
Normative protocol behavior is defined in `PROTOCOL.md`.

## Layered Mapping

FTF can be viewed as three stacked layers:

1. Identity fibers
- author keys/signatures define independent signed streams.

2. Replay base
- verified messages are ordered deterministically by `(t, mh)`.

3. Lineage projection
- `trace` projects verified events into artifact/event/edge/note structure.

In shorthand:

```text
identity fibers
      ↓
deterministic replay surface (t, mh)
      ↓
artifact lineage projection (trace)
```

## Why This Helps

- It clarifies separation of concerns:
  - identity (`author`, signature)
  - ordering (replay key)
  - structure (lineage graph)
  - annotations (`attest`, `revoke`, `pending_fetch`)
- It explains why replay determinism and trace determinism are robust under
  implementation details (map iteration, field order, etc.).

## Notes As Fields

`attest` and `revoke` are annotation fields over lineage, not structural
mutations.

- `attest`: positive evidence
- `revoke`: negative evidence

The graph remains append-only; notes add interpretation without rewriting
history.

## Alias As External Section

Alias resolution is a separate naming layer over canonical artifact identity:

```text
alias : Name -> ArtifactHash
```

This keeps human naming concerns independent from core replay/lineage rules.

## Forward Compatibility

This layered architecture allows growth (spaces, federation, transport) without
changing the protocol core:

- keep wire + replay fixed
- evolve distribution/identity workflows around it

That is the intended scaling path for post-`v0.1.x` work.
