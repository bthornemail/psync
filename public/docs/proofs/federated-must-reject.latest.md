# Federated Must-Reject Receipt (Latest)

- Date (UTC): 2026-03-06T21:05:00Z
- Repository: `/root/psync`
- Scope: bounded fail-closed behavior for cross-space references without explicit handoff, malformed handoff imports, and foreign-local authority assumptions

## Goal

Prove the negative federation laws:

1. no reference without receipt
2. no import without valid receipt
3. no authority without local grant

This receipt uses only existing local spaces commands and the current fail-closed wrappers.

## Scenario Setup

Create local provenance in `alpha`:

```bash
ftf space new alpha
ftf identity derive --space alpha --role auditor
ftf identity use --space alpha --member auditor
printf 'alpha dataset\n' > dataset.bin
ftf put dataset.bin --space alpha
printf 'alpha model\n' > model-a.bin
ftf xform train-alpha --space alpha --input dataset.bin --output model-a.bin
ftf attest model-a.bin --space alpha --claim produced
```

Bounded foreign identifiers:

- alpha model artifact: `12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646`
- alpha xform event: `122077fd837cf4209dfb6caa355f8a2528775aee266f67213dc2811b0d2ae0a01e87`
- alpha attest event: `1220ac7604b2cdac4ed9e2af8324add1026f1583b20d4b015bd52155c9245ff029bb`

Create local `beta` space:

```bash
ftf space new beta
ftf identity derive --space beta --role auditor
ftf identity use --space beta --member auditor
printf 'beta review\n' > review.bin
```

## Case 1: Reject Cross-Space Reference Without Explicit Handoff

Command:

```bash
ftf xform review-foreign --space beta \
  --input 12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646 \
  --output review.bin
```

Observed result:

```text
exit=1
ftf: user error (input artifact not found in local space: 12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646)
```

Claim:

- raw foreign artifact hashes are not valid local xform inputs
- `beta` cannot reference `alpha` lineage without an explicit local receipt artifact

## Case 2: Reject Invalid Imported Handoff Receipt

Malformed handoff artifact:

```bash
cat > bad-handoff.json <<'EOF'
{"from_space":"alpha","artifact":"12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646","xform":"122077fd837cf4209dfb6caa355f8a2528775aee266f67213dc2811b0d2ae0a01e87","attest":"bogus"}
EOF
ftf put bad-handoff.json --space beta
```

Observed local import output:

```text
artifact: 122080a844635e3d193addd3e5c222c619ceb713802186754b64be28de482d7f138c
event:    1220b58367dee8c9b839483990dbc02575d768c1b9b2822d137d238b42832628c764
topic:    provenance/main
```

Attempted use of foreign model referenced by the malformed handoff:

```bash
ftf xform review-bad-handoff --space beta \
  --input 12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646 \
  --output review.bin
```

Observed result:

```text
exit=1
ftf: user error (input artifact not found in local space: 12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646)
```

Topic length check:

```text
lines_before=1
lines_after=1
```

Trace of the malformed handoff artifact:

```ndjson
{"kind":"trace.header","root":"122080a844635e3d193addd3e5c222c619ceb713802186754b64be28de482d7f138c","version":1}
{"h":"122080a844635e3d193addd3e5c222c619ceb713802186754b64be28de482d7f138c","kind":"trace.artifact","role":"root","status":"ok"}
{"artifact":"122080a844635e3d193addd3e5c222c619ceb713802186754b64be28de482d7f138c","author":"eb04c684d06695a80f723350f1a000f8971d366f144d0653e15e6e456df20207","etype":"put","kind":"trace.event","mh":"1220b58367dee8c9b839483990dbc02575d768c1b9b2822d137d238b42832628c764","t":1}
{"from":"event:1220b58367dee8c9b839483990dbc02575d768c1b9b2822d137d238b42832628c764","kind":"trace.edge","rel":"produces","to":"artifact:122080a844635e3d193addd3e5c222c619ceb713802186754b64be28de482d7f138c"}
```

Observed absence check:

```text
bad_trace_has_alpha_model=no
```

Claim:

- malformed handoff content is treated as an opaque local artifact, not an imported foreign lineage
- failed use of the foreign model does not append new local lineage
- no accepted local provenance is created for the foreign artifact

## Case 3: Reject Foreign-Local Authority Assumptions

Command:

```bash
ftf attest 1220ac7604b2cdac4ed9e2af8324add1026f1583b20d4b015bd52155c9245ff029bb \
  --space beta \
  --claim inherited
```

Observed result:

```text
exit=1
ftf: user error (target not found in verified space/topic: 1220ac7604b2cdac4ed9e2af8324add1026f1583b20d4b015bd52155c9245ff029bb)
```

Claim:

- a foreign attest event does not grant local authority inside `beta`
- local notes require locally reachable targets in the verified topic view

## Proof Receipt

- Bounded negative federation scenario in fresh local workspaces
- Baseline protocol gate: `bash verify-wire.sh`

Observed protocol anchor:

```text
[verify-wire] ok wire conformance
```

## Verified Claims

- no reference without receipt
- no import without valid receipt
- no authority without local grant
- failed federation attempts do not create hidden local lineage
- the bounded federation boundary is fail-closed on the current wire surface

## Conclusion

Federated locality now has both sides documented:

- positive explicit handoff: [federated-handoff.latest.md](/root/psync/docs/proofs/federated-handoff.latest.md)
- negative fail-closed federation boundary: this receipt

Cross-space provenance remains explicit, local, and non-inheriting by default.
