# Topology Report Adapter Lane (`topology_report.v0`)

Status: proposed bounded adapter lane.

This lane adds a deterministic advisory report artifact emitted from `waveform-core` and bound into FTF using existing verbs. It does **not** change core FTF wire semantics and does **not** add core verbs.

## 1. Goal

Define a deterministic adapter path:

```text
signal/trace
  -> waveform-core
  -> topology_report.v0
  -> ftf put
  -> ftf attest (subject + evidence digest)
  -> ftf trace
  -> projection join
```

The lane must preserve:

- waveform-core projection-only behavior
- append-only provenance law in FTF
- deterministic replay and rendering

## 2. Artifact Kind

The new payload kind is:

```text
topology_report.v0
```

It is a standard content-addressed artifact body (advisory report), not executable policy.

## 3. Canonical Payload

Example canonical object:

```json
{
  "kind": "topology_report.v0",
  "subject": {
    "kind": "artifact",
    "hash": "1220..."
  },
  "source": {
    "tool": "waveform-core",
    "version": "1.0.0"
  },
  "input": {
    "mode": "samples",
    "digest": "sha256:..."
  },
  "embedding": {
    "method": "takens",
    "delay": 12,
    "dimension": 3
  },
  "classification": {
    "periodic": true,
    "chaotic": false,
    "topology_changed": false,
    "confidence": 0.87
  },
  "persistence": {
    "h0_count": 1,
    "h1_count": 1,
    "dominant_h1": {
      "birth": 0.12,
      "death": 0.91,
      "persistence": 0.79
    }
  },
  "labels": [
    "periodic",
    "circle-like"
  ],
  "summary": {
    "class": "periodic-loop",
    "note": "single dominant H1 feature"
  }
}
```

## 4. ABI Keyset (Top-Level)

Frozen top-level keys:

```text
kind
subject
source
input
embedding
classification
persistence
labels
summary
```

Required fields:

```text
kind
subject.hash
source.tool
source.version
classification.periodic
classification.chaotic
classification.topology_changed
classification.confidence
summary.class
```

Optional-but-stable fields:

```text
input
embedding
persistence
labels
summary.note
```

## 5. Determinism Rules

`topology_report.v0` must be byte-stable for identical inputs.

Rules:

- canonical key ordering
- stable array ordering
- fixed numeric formatting policy
- no timestamps
- no host metadata
- no random identifiers
- no environment-dependent paths

Numeric formatting policy must be documented by the adapter and must be stable across reruns.

## 6. Subject Binding Model

First bounded subject model:

```json
"subject": {
  "kind": "artifact",
  "hash": "1220..."
}
```

One report binds to one analyzed subject artifact hash.

## 7. FTF Binding Model (No New Verbs)

Use existing FTF surfaces:

1. Store report with `put`
2. Bind via `attest` to analyzed subject, with evidence set to report artifact digest

Recommended claim shape:

```text
about = artifact:<subject-hash>
claim = topology_report.v0
evidence = <report-artifact-hash>
```

## 8. Trace Recovery Model

Joined recovery path:

1. `trace` root subject artifact
2. find `trace.note` with `note_type="attest"` and `claim="topology_report.v0"`
3. resolve evidence hash to report artifact
4. decode report JSON
5. render provenance + topology together

## 9. Projection Join Contract

Join provenance side:

- artifact node
- producing event
- dependency edges
- attest/revoke overlays

With topology side:

- class label
- confidence
- dominant feature summary
- optional topology glyph family

## 10. Must-Reject Cases

The adapter lane must fail closed on:

1. missing `kind`
2. wrong `kind`
3. missing `subject.hash`
4. malformed subject hash
5. confidence outside `[0,1]`
6. non-canonical serialization in golden path
7. non-deterministic numeric formatting
8. forbidden classifier combination (if configured), e.g. `periodic=true` and `chaotic=true`
9. evidence hash mismatch between report bytes and claimed digest
10. attest subject different from report subject

## 11. Replay-Equivalence Assertions

For identical input:

- identical report bytes
- identical report digest
- identical attest evidence binding
- identical joined projection summary

## 12. Recommended `summary.class` Enum (v0)

```text
periodic-loop
toroidal
chaotic-fragmented
noise-like
degenerate
unknown
```

## 13. Minimal Lane Scripts

Suggested script set:

```text
scripts/topology-report-v0-golden.sh
scripts/topology-report-v0-must-reject.sh
scripts/check-topology-report-v0-contract.sh
```

## 14. Boundary Rules

`waveform-core` must not:

- emit signed FTF messages directly
- define FTF authority semantics
- mutate topic logs

Adapter may:

- invoke waveform-core
- canonicalize report bytes
- emit advisory report artifacts

FTF must:

- treat report as ordinary artifact
- bind through existing verbs only
- preserve append-only semantics

## 15. One-Line Principle

`waveform-core` emits advisory geometry, FTF binds it lawfully, projection surfaces join it visibly.
