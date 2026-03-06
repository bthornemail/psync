# Attest Semantics Receipt (Latest)

- Date (UTC): 2026-03-06T03:26:32Z
- Repository: `/root/psync`
- Scenario: bounded attest annotation on `realm=ftf`, `topic=provenance/attest-demo`

## Scenario

- `put(A)` (materialized in local CAS)
- `xform(inputs=[A], outputs=[B])`
- `attest(about=MH2, claim="reproduced")` where `MH2` is the xform event hash
- root trace query is `B`

Expected semantics:

- history remains present (`put` and `xform` events still emitted)
- attest is emitted as `trace.note` annotation
- no mutation/deletion of lineage edges

## Inputs

- `A = 1220b6d98a430f1af52dc21a12e90db407c13f91ad74b1637b8dafbbc53c5a84af39`
- `B = 12203b141272f804d1f47614d0c94206168215ef8f3cf2d43259ed45a4ce57f5693e`
- `MH1 (put) = 122098f64bd5fcb4eb073ee5581329e0444c372ae678b57190091b4e19720f01df13`
- `MH2 (xform) = 1220ab14dceaa1ab54e67728f6ac2201a223d38a50e790a74eaf8883136c68ee459e`
- `MH3 (attest) = 12205fd9bb3085813bbfc51c5a2d7b2880f9d87ba1801a514f9eb6057384e7ec5f71`

## Query Command

```bash
ftf trace --realm ftf --topic provenance/attest-demo "$B" "$TRACE_TOPIC_FILE"
```

## Trace Output

```ndjson
{"kind":"trace.header","root":"12203b141272f804d1f47614d0c94206168215ef8f3cf2d43259ed45a4ce57f5693e","version":1}
{"h":"12203b141272f804d1f47614d0c94206168215ef8f3cf2d43259ed45a4ce57f5693e","kind":"trace.artifact","role":"root","status":"ok"}
{"h":"1220b6d98a430f1af52dc21a12e90db407c13f91ad74b1637b8dafbbc53c5a84af39","kind":"trace.artifact","role":"dependency","status":"ok"}
{"artifact":"1220b6d98a430f1af52dc21a12e90db407c13f91ad74b1637b8dafbbc53c5a84af39","author":"1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f","etype":"put","kind":"trace.event","mh":"122098f64bd5fcb4eb073ee5581329e0444c372ae678b57190091b4e19720f01df13","t":1}
{"author":"1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f","etype":"xform","inputs":["1220b6d98a430f1af52dc21a12e90db407c13f91ad74b1637b8dafbbc53c5a84af39"],"kind":"trace.event","mh":"1220ab14dceaa1ab54e67728f6ac2201a223d38a50e790a74eaf8883136c68ee459e","outputs":["12203b141272f804d1f47614d0c94206168215ef8f3cf2d43259ed45a4ce57f5693e"],"t":2,"tool":"1220dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"}
{"about":"event:1220ab14dceaa1ab54e67728f6ac2201a223d38a50e790a74eaf8883136c68ee459e","author":"1eefa6ca348764473450f89ac8f2c06ff38d88617820493acf68ef7a0b0acb0f","claim":"reproduced","kind":"trace.note","mh":"12205fd9bb3085813bbfc51c5a2d7b2880f9d87ba1801a514f9eb6057384e7ec5f71","note_type":"attest","t":3}
{"from":"artifact:1220b6d98a430f1af52dc21a12e90db407c13f91ad74b1637b8dafbbc53c5a84af39","kind":"trace.edge","rel":"consumed_by","to":"event:1220ab14dceaa1ab54e67728f6ac2201a223d38a50e790a74eaf8883136c68ee459e"}
{"from":"event:122098f64bd5fcb4eb073ee5581329e0444c372ae678b57190091b4e19720f01df13","kind":"trace.edge","rel":"produces","to":"artifact:1220b6d98a430f1af52dc21a12e90db407c13f91ad74b1637b8dafbbc53c5a84af39"}
{"from":"event:1220ab14dceaa1ab54e67728f6ac2201a223d38a50e790a74eaf8883136c68ee459e","kind":"trace.edge","rel":"produces","to":"artifact:12203b141272f804d1f47614d0c94206168215ef8f3cf2d43259ed45a4ce57f5693e"}
```

## Verified Claims

- Attest appears as annotation: `{"kind":"trace.note","note_type":"attest",...}`.
- Attest carries positive evidence (`claim:"reproduced"`).
- `xform` event and lineage edges remain present after attest.
- Query semantics stay append-only; attest does not mutate structure.
