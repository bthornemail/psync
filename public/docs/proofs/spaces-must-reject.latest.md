# Spaces Must-Reject Receipt (Latest)

- Date (UTC): 2026-03-06T20:39:00Z
- Repository: `/root/psync`
- Scope: bounded fail-closed behavior for space-local `attest` / `revoke` wrappers and topic append guards

## Goal

Prove that the space-local wrappers reject invalid targets and malformed inputs, and refuse to append to a topic once replay has entered a rejected state.

Covered cases:

1. unresolved target rejection
2. malformed evidence hash rejection
3. unreachable revoke target rejection
4. topic replay failure guard

## Preconditions

- fresh local space `lab`
- active member `auditor`
- default provenance topic `provenance/main`
- baseline happy-path commands still available

## Baseline Setup

```bash
ftf space new lab
ftf identity derive --space lab --role auditor
ftf identity use --space lab --member auditor
printf 'dataset\n' > a.bin
ftf put a.bin --space lab
```

Observed baseline output:

```text
artifact: 12206b30f95b2f4c06ff5b7cc6d3b1c617745743c5c214966d9b978eaa4f48b5adae
event:    122041e95e9088a1652af28b8d2160112569c25af3be01ba69b041f41cf392163c82
topic:    provenance/main
```

This establishes a bounded valid topic before the rejection cases are exercised.

## Case 1: Unresolved Target Rejection

Command:

```bash
ftf attest does/not/exist --space lab --claim reproduced
```

Observed result:

```text
exit=1
ftf: user error (unable to resolve trace root: does/not/exist)
```

Claim:

- unresolved path / alias / hash targets fail before any append occurs

## Case 2: Malformed Evidence Hash Rejection

Command:

```bash
ftf attest a.bin --space lab --claim reproduced --evidence not-a-hash
```

Observed result:

```text
exit=1
option --evidence: "base16: input: invalid encoding at offset: 0"

Usage: ftf attest HASH_OR_ALIAS_OR_PATH --claim CLAIM [--space NAME]
                  [--evidence MH_HEX] [--evidence-file FILE] [--topic TOPIC]

  Append a signed attest note in a space
```

Claim:

- malformed evidence hashes are rejected at CLI parse time
- no note event is emitted

## Case 3: Unreachable Revoke Target Rejection

Command:

```bash
ftf revoke 1220aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --space lab --reason bad
```

Observed result:

```text
exit=1
ftf: user error (target not found in verified space/topic: 1220aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)
```

Claim:

- `revoke --space` is fail-closed against arbitrary valid-looking hashes
- target must already be reachable in the verified topic view

## Case 4: Topic Replay Failure Guard

Bounded corruption step:

```bash
sed 's/"sig":"[^"]*"/"sig":"00"/' \
  .ftf/spaces/lab/topics/provenance/main.ndjson \
  > .ftf/spaces/lab/topics/provenance/main.ndjson.bad
mv .ftf/spaces/lab/topics/provenance/main.ndjson.bad \
  .ftf/spaces/lab/topics/provenance/main.ndjson
```

Corrupted topic excerpt:

```ndjson
{"author":"878f5a686d9c7262de53608dd65f595927715660df13eeec4997ec3bf7ffbc3d","body":{"artifact":{"hash":"12206b30f95b2f4c06ff5b7cc6d3b1c617745743c5c214966d9b978eaa4f48b5adae"},"kind":"put"},"caps":[],"prev":null,"realm":"ftf:lab","sig":"00","t":1,"topic":"provenance/main","v":1,"witness":null}
```

Attempted append:

```bash
ftf put a.bin --space lab
```

Observed result:

```text
exit=1
ftf: user error (topic has rejected messages: provenance/main)
```

Topic length check:

```text
lines_before=1
lines_after=1
```

Claim:

- wrapper commands refuse append once verified replay reports rejected messages
- failed append does not mutate topic length

## Proof Receipt

- Must-reject scenario capture: bounded local run in fresh temp workspace
- Baseline protocol gate: `bash verify-wire.sh`

Observed protocol anchor:

```text
[verify-wire] ok wire conformance
```

## Verified Claims

- `attest --space` rejects unresolved targets
- `attest --space` rejects malformed evidence hashes
- `revoke --space` rejects unreachable targets outside the verified topic surface
- `put --space` refuses append against topics with rejected messages
- topic append guards are fail-closed: rejected replay state does not produce partial appends
- must-reject behavior is layered on top of an unchanged green wire surface

## Conclusion

Spaces are proven in both directions:

- happy-path governed workflow: [spaces-workflow.latest.md](/root/psync/docs/proofs/spaces-workflow.latest.md)
- fail-closed wrapper behavior: this receipt

The space-local wrappers do not merely function; they reject invalid and unsafe states deterministically.
