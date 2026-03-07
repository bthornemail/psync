# Full Body Rust Conformance Receipt (Latest)

- Date (UTC): 2026-03-06T04:39:47Z
- Repository: `/root/psync`
- Scope: cross-language verification for full body-kind surface in Rust verifier

## Scenario

A signed topic stream (`realm=ftf`, `topic=provenance/fullbody`) with strict
append-only linkage and monotone `t`, containing:

1. `put`
2. `use`
3. `xform`
4. `attest`
5. `revoke`

All messages are produced by the Haskell CLI (`ftf sign-msg`) and verified by
Rust (`ftf-verify verify-topic`).

## Conformance Command

```bash
bash verify-wire.sh
```

## Rust Verification Segment

```text
[verify-wire] Cross-checking full body-kind verification in Rust
Running `target/debug/ftf-verify verify-topic ftf provenance/fullbody`
verified=5
OK 1220dd3d90bd9308daae3ce9a60bec12ab7952ccf2c1c2bdb26c5419cb081cb7b4c9 t=1
OK 12206a1ff60415a0beea7d1aa57e8d85bfb0d06c59a55cba121b8bd1df3a029e5ba1 t=2
OK 12209f8a47a1d306c4e041a518f42d18f50035aab0ac702b8f941e72f69544bc4f0b t=3
OK 1220f9075a988ec2aee1173a44e59be51151f745f4cf263baa31762a95487eb390bb t=4
OK 1220369f4d235fab4e228ec6cf5edf45a9d67519d15e9d89b60c630df1eed1031317 t=5
rejected=0
```

## Verified Claims

- Rust verifier accepts all five body kinds in deterministic replay:
  - `put`, `use`, `xform`, `attest`, `revoke`
- Cross-language wire compatibility holds for full body-kind CBOR projection.
- Signature and linkage gates remain fail-closed (`rejected=0` in this bounded fixture).
