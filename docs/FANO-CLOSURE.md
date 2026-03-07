# Minimal Closure (Fano-Style) View

This note describes a minimal-primitive interpretation of FTF operations.

Important: this is an explanatory symmetry model, not a formal requirement in
the protocol spec. Normative behavior is in `PROTOCOL.md`.

## The Seven-Role Lens

FTF has six protocol body kinds plus one projection command:

1. `put`
2. `use`
3. `xform`
4. `attest`
5. `revoke`
6. `alias_claim`
7. `trace` (projection/query)

This seven-role set behaves like a minimal closure system:

- material flow: `put/use/xform`
- epistemic judgment: `attest/revoke`
- naming: `alias_claim`
- observability/projection: `trace`

## Why `trace` Is Part Of Closure

Without `trace`, event streams exist but the causal structure is not directly
recoverable for inspection. `trace` closes the loop from signed events to
observable lineage.

```text
events -> replay -> trace -> inspectable causality
```

## Triple Interactions

Common closure triples in practice:

- `put + use -> xform` (material causality)
- `xform + attest -> trusted evidence`
- `xform + revoke -> corrected evidence`
- `alias_claim + artifact hash -> human reference`
- `trace + verified stream -> observable lineage`

These triples explain why the primitive set feels complete without expanding
core verbs.

## Practical Guidance

Because this set is already minimal-and-complete for `v0.1.x`:

- avoid adding core protocol verbs unless strictly necessary
- add capability through outer layers (spaces, federation, transport)
- preserve deterministic replay + append-only semantics

This keeps FTF small, reliable, and auditable.
