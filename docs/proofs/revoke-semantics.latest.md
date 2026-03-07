# Revoke Semantics Receipt (Latest)

- Date (UTC): 2026-03-06T03:14:56Z
- Repository: `/root/psync`
- Scenario: bounded revoke annotation on `realm=ftf`, `topic=provenance/revoke-demo`

## Scenario

- `put(A)` (materialized in local CAS)
- `xform(inputs=[A], outputs=[B])`
- `revoke(target=MH2, reason="bounded-conformance-test")` where `MH2` is the xform event hash
- root trace query is `B`

Expected semantics:

- history remains present (`put` and `xform` events still emitted)
- revoke is emitted as `trace.note` annotation
- no deletion/rewrite of prior lineage edges

## Inputs

- `A = 12206720429cedd7826199b5505d26a1ee1b51e278a465dd17f4cc2c14dca140d121`
- `B = 12204de4fea91b2877ad465c58a58194cad77fbcc49756d4c34ed7decb983b3f34e7`
- `MH1 (put) = 12202966671529f29cd5aa0d2cdaf2638cb7efef83f40ca622e2dc1d9d11a07cc3fa`
- `MH2 (xform) = 12203c7d633baa7438432bca7f1ddbb5612cdce235df0f4746b8f61cacc33727e281`
- `MH3 (revoke) = 1220558f02e9c1f483734cc13bbee243533ada6ba907a25e41e75575452a646ce4e3`

## Query Command

```bash
ftf trace --realm ftf --topic provenance/revoke-demo "$B" "$TRACE_TOPIC_FILE"
```

## Trace Output

```ndjson
{"kind":"trace.header","root":"12204de4fea91b2877ad465c58a58194cad77fbcc49756d4c34ed7decb983b3f34e7","version":1}
{"h":"12204de4fea91b2877ad465c58a58194cad77fbcc49756d4c34ed7decb983b3f34e7","kind":"trace.artifact","role":"root","status":"ok"}
{"h":"12206720429cedd7826199b5505d26a1ee1b51e278a465dd17f4cc2c14dca140d121","kind":"trace.artifact","role":"dependency","status":"ok"}
{"artifact":"12206720429cedd7826199b5505d26a1ee1b51e278a465dd17f4cc2c14dca140d121","author":"1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f","etype":"put","kind":"trace.event","mh":"12202966671529f29cd5aa0d2cdaf2638cb7efef83f40ca622e2dc1d9d11a07cc3fa","t":1}
{"author":"1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f","etype":"xform","inputs":["12206720429cedd7826199b5505d26a1ee1b51e278a465dd17f4cc2c14dca140d121"],"kind":"trace.event","mh":"12203c7d633baa7438432bca7f1ddbb5612cdce235df0f4746b8f61cacc33727e281","outputs":["12204de4fea91b2877ad465c58a58194cad77fbcc49756d4c34ed7decb983b3f34e7"],"t":2,"tool":"1220cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}
{"about":"event:12203c7d633baa7438432bca7f1ddbb5612cdce235df0f4746b8f61cacc33727e281","author":"1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f","kind":"trace.note","mh":"1220558f02e9c1f483734cc13bbee243533ada6ba907a25e41e75575452a646ce4e3","note_type":"revoke","reason":"bounded-conformance-test","t":3}
{"from":"artifact:12206720429cedd7826199b5505d26a1ee1b51e278a465dd17f4cc2c14dca140d121","kind":"trace.edge","rel":"consumed_by","to":"event:12203c7d633baa7438432bca7f1ddbb5612cdce235df0f4746b8f61cacc33727e281"}
{"from":"event:12202966671529f29cd5aa0d2cdaf2638cb7efef83f40ca622e2dc1d9d11a07cc3fa","kind":"trace.edge","rel":"produces","to":"artifact:12206720429cedd7826199b5505d26a1ee1b51e278a465dd17f4cc2c14dca140d121"}
{"from":"event:12203c7d633baa7438432bca7f1ddbb5612cdce235df0f4746b8f61cacc33727e281","kind":"trace.edge","rel":"produces","to":"artifact:12204de4fea91b2877ad465c58a58194cad77fbcc49756d4c34ed7decb983b3f34e7"}
```

## Verified Claims

- Revoke appears as annotation: `{"kind":"trace.note","note_type":"revoke",...}`.
- Revoke targets the xform event (`about:"event:MH2"`), not artifact deletion.
- `xform` event and `produces` edges remain present after revoke.
- Query semantics remain fail-closed and append-only for lineage history.
