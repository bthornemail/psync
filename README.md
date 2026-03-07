# FTF - Frozen Trace Fabric

[![Conformance](https://github.com/FreedomAutonomyReciprocitySoverignty/psync/actions/workflows/conformance.yml/badge.svg)](https://github.com/FreedomAutonomyReciprocitySoverignty/psync/actions/workflows/conformance.yml)
[![Release Matrix](https://github.com/FreedomAutonomyReciprocitySoverignty/psync/actions/workflows/release-matrix.yml/badge.svg)](https://github.com/FreedomAutonomyReciprocitySoverignty/psync/actions/workflows/release-matrix.yml)

**FTF** is a deterministic provenance protocol for content-addressed artifacts.

It provides:

- canonical wire encoding
- deterministic replay ordering
- signed append-only message streams
- artifact lineage tracing
- annotation semantics (`attest`, `revoke`)
- cross-language verification

This repository contains the **reference implementation** of the protocol.

## Repository Layout

```text
app/                 Haskell reference CLI source
rust/ftf-verify/     Independent Rust verifier
public/              Static Observatory UI
docs/proofs/         Conformance receipts
scripts/             Release and tooling
verify-wire.sh       End-to-end conformance harness
PROTOCOL.md          Frozen protocol specification
```

## Protocol

The protocol specification is frozen in:

```text
PROTOCOL.md
```

It defines:

- canonical CBOR projection
- message preimage
- multihash format
- Ed25519 signing rules
- replay ordering `(t, mh)`
- supported body kinds

Body kinds:

```text
put
use
xform
attest
revoke
alias_claim
```

Architecture/model docs:

- [docs/ARCHITECTURE.md](/root/psync/docs/ARCHITECTURE.md)
- [docs/CATEGORY.md](/root/psync/docs/CATEGORY.md)
- [docs/ARCHITECTURE-BUNDLE.md](/root/psync/docs/ARCHITECTURE-BUNDLE.md)
- [docs/FANO-CLOSURE.md](/root/psync/docs/FANO-CLOSURE.md)
- [docs/topology-report-v0.md](/root/psync/docs/topology-report-v0.md)
- [docs/releases/v0.1.0-design-rationale.md](/root/psync/docs/releases/v0.1.0-design-rationale.md)
- [docs/v0.2.0-spaces-cli-spec.md](/root/psync/docs/v0.2.0-spaces-cli-spec.md)
- [docs/cli/space-commands.md](/root/psync/docs/cli/space-commands.md)
- [docs/roadmap/v0.2.0-checklist.md](/root/psync/docs/roadmap/v0.2.0-checklist.md)

## Build

### Haskell CLI

```bash
cabal build --builddir=.cabal-ftf
```

Binary:

```text
ftf
```

### Rust Verifier

```bash
cd rust/ftf-verify
cargo build
```

Binary:

```text
ftf-verify
```

## Conformance Verification

Run the end-to-end harness:

```bash
bash verify-wire.sh
```

Expected final output includes:

```text
verified=5
rejected=0
[verify-wire] ok wire conformance
```

This validates:

- wire encoding
- signature verification
- deterministic replay
- alias resolution
- full body-kind parity between Haskell and Rust

## CI/CD

GitHub Actions workflows:

- `.github/workflows/conformance.yml`
  - Runs `bash verify-wire.sh` on PRs and pushes to main/master.
- `.github/workflows/release-matrix.yml`
  - Builds release artifacts for Linux/macOS/Windows.
  - Publishes tagged releases (`v*`) with binaries and checksums.

## Observatory

The repository includes a **static inspection UI** in:

```text
public/
```

Run locally:

```bash
python3 -m http.server 8000 -d public
```

Open:

```text
http://localhost:8000
```

Capabilities:

- deterministic trace visualization
- replay frontier scrubber
- artifact/event inspection
- alias chain view
- proof receipt viewer
- drag/drop NDJSON trace loading

The UI supports:

- embedded sample data
- hosted fetch assets
- local file inspection

## Spaces Preview

The first `v0.2.0` workflow commands are now available:

```bash
ftf space new <name> [--realm <realm>] [--path <dir>] [--show-seed]
ftf space show <name>
ftf space ls
ftf identity derive [--space <name>] (--role <role> | --path <hd-path>)
ftf identity show [--space <name>]
ftf identity use [--space <name>] --member <id>
ftf alias set <logical-id> <artifact_mh_hex> [--space <name>] [--topic <topic>]
ftf alias get <logical-id> [--space <name>] [--topic <topic>]
ftf alias ls [--space <name>] [--topic <topic>]
ftf xform <label> --space <name> --input <hash-or-path> --output <hash-or-path> [--tool <mh>] [--params <file>] [--receipt <file>] [--topic <topic>]
ftf attest <hash-or-alias-or-path> --space <name> --claim <claim> [--evidence <mh>] [--evidence-file <path>] [--topic <topic>]
ftf revoke <hash-or-alias-or-path> --space <name> --reason <reason> [--superseded-by <mh>] [--topic <topic>]
ftf put <path> --space <name> [--topic <topic>]
ftf trace [--space <name>] [--topic <topic>] <hash-or-alias-or-path>
```

This creates local space scaffolding with `space.json`, `topics/`, `cas/`,
`keys/`, initializes the active space if none exists yet, supports
readback/listing of local spaces, supports deterministic member-key
derivation from the space root identity, supports switching the active
local signer, can append/resolve alias claims in a space-local alias
topic, can append signed `put`, `xform`, `attest`, and `revoke` events
in the space topic log, and can inspect lineage by path/alias/hash. In
space mode, `trace` resolves targets in this order: path, alias, then
raw multihash hex.

## Proof Receipts

Protocol behavior is demonstrated by bounded receipts in:

```text
docs/proofs/
```

Included proofs:

- wire conformance
- trace semantics
- revoke semantics
- attest semantics
- Rust full-body conformance

These documents capture exact inputs and outputs used to validate the protocol.

## Release Artifacts

Release builds contain:

```text
ftf
ftf-verify
public/
docs/proofs/
verify-wire.sh
PROTOCOL.md
```

Checksums are provided via:

```text
SHA256SUMS
```

## Status

**v0.1.0 - Reference Implementation**

The system provides a deterministic protocol surface suitable for:

- auditors
- integrators
- provenance tooling
- research systems

## License

Apache-2.0
