# Trace Semantics Receipt (Latest)

- Date (UTC): 2026-03-06T03:10:01Z
- Repository: `/root/psync`
- Scenario: bounded provenance on `realm=ftf`, `topic=provenance/demo`

## Scenario

- `put(A)` where `A` is materialized via `cas-put`
- `xform(inputs=[A,U], outputs=[B])`
- `U` is a valid artifact hash reference but not materialized in local CAS
- Root query is `B`

Expected semantics:

- `A -> status:"ok"`
- `U -> status:"pending_fetch"`
- `B (root) -> status:"ok"`

## Inputs

- `A = 12203d7a63bffd8ed881b52452a37e9d777e58379d88aad75a070d0c0533ca18ab27`
- `U = 1220170cdb96825c9894f1a5d71c6d3bcfbeb9ab1b5191b2b017d113e7c386e2bfdc`
- `B = 1220b9768063b9333d12b3a4ef8d35f1716f4f33749a60c3f8af47885c4f2baf5464`

## Query Command

```bash
ftf trace --realm ftf --topic provenance/demo "$B" "$TRACE_TOPIC_FILE"
```

## Trace Output

```ndjson
{"kind":"trace.header","root":"1220b9768063b9333d12b3a4ef8d35f1716f4f33749a60c3f8af47885c4f2baf5464","version":1}
{"h":"1220170cdb96825c9894f1a5d71c6d3bcfbeb9ab1b5191b2b017d113e7c386e2bfdc","kind":"trace.artifact","role":"dependency","status":"pending_fetch"}
{"h":"12203d7a63bffd8ed881b52452a37e9d777e58379d88aad75a070d0c0533ca18ab27","kind":"trace.artifact","role":"dependency","status":"ok"}
{"h":"1220b9768063b9333d12b3a4ef8d35f1716f4f33749a60c3f8af47885c4f2baf5464","kind":"trace.artifact","role":"root","status":"ok"}
{"artifact":"12203d7a63bffd8ed881b52452a37e9d777e58379d88aad75a070d0c0533ca18ab27","author":"1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f","etype":"put","kind":"trace.event","mh":"122053662bbbf27c99eaf96c0ae6b305e0908ba4c205b478802ad53bd8a81ee4852b","t":1}
{"author":"1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f","etype":"xform","inputs":["1220170cdb96825c9894f1a5d71c6d3bcfbeb9ab1b5191b2b017d113e7c386e2bfdc","12203d7a63bffd8ed881b52452a37e9d777e58379d88aad75a070d0c0533ca18ab27"],"kind":"trace.event","mh":"12205d6bcc7eac6d39ed8346c326b3a91967d944206b001dd72b7187bb37d576825a","outputs":["1220b9768063b9333d12b3a4ef8d35f1716f4f33749a60c3f8af47885c4f2baf5464"],"t":2,"tool":"1220bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}
{"about":"artifact:1220170cdb96825c9894f1a5d71c6d3bcfbeb9ab1b5191b2b017d113e7c386e2bfdc","kind":"trace.note","note_type":"pending_fetch"}
{"from":"artifact:1220170cdb96825c9894f1a5d71c6d3bcfbeb9ab1b5191b2b017d113e7c386e2bfdc","kind":"trace.edge","rel":"consumed_by","to":"event:12205d6bcc7eac6d39ed8346c326b3a91967d944206b001dd72b7187bb37d576825a"}
{"from":"artifact:12203d7a63bffd8ed881b52452a37e9d777e58379d88aad75a070d0c0533ca18ab27","kind":"trace.edge","rel":"consumed_by","to":"event:12205d6bcc7eac6d39ed8346c326b3a91967d944206b001dd72b7187bb37d576825a"}
{"from":"event:122053662bbbf27c99eaf96c0ae6b305e0908ba4c205b478802ad53bd8a81ee4852b","kind":"trace.edge","rel":"produces","to":"artifact:12203d7a63bffd8ed881b52452a37e9d777e58379d88aad75a070d0c0533ca18ab27"}
{"from":"event:12205d6bcc7eac6d39ed8346c326b3a91967d944206b001dd72b7187bb37d576825a","kind":"trace.edge","rel":"produces","to":"artifact:1220b9768063b9333d12b3a4ef8d35f1716f4f33749a60c3f8af47885c4f2baf5464"}
```

## Verified Claims

- Root artifact `B` is materialized (`status:"ok"`).
- Dependency `A` is materialized (`status:"ok"`).
- Dependency `U` is unresolved locally and marked `pending_fetch`.
- Query output is deterministic for this fixed signed input stream.
