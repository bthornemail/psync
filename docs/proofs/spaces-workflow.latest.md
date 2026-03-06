# Spaces Workflow Receipt (Latest)

- Date (UTC): 2026-03-06T20:14:59Z
- Repository: `/root/psync`
- Scope: bounded end-to-end space-local provenance workflow on `space=lab`

## Goal

Prove that a space-local provenance workflow supports:

- local artifact storage
- signed transform events
- signed attest notes on artifacts
- signed revoke notes on events
- alias resolution
- deterministic trace projection

without changing core wire semantics.

## Preconditions

- space `lab` exists
- active member `auditor` exists and is selected
- default provenance topic is `provenance/main`
- default alias topic is `alias/main`

## Scenario

### 1. Create / select space

```bash
ftf space new lab --show-seed
```

```text
Space: lab
Realm: ftf:lab
Space ID: 1220e290c9955010d133e7f1f122a3d05cabe69ee9e30445a1dbcf1cf1a25c436662
Created: .ftf/spaces/lab
Seed: fac1861345238428f0cbe13ae2014e3d0e95836b8025d14dcecdf1a97bb4936e
```

### 2. Derive / activate member

```bash
ftf identity derive --space lab --role auditor
ftf identity use --space lab --member auditor
```

```text
Member: auditor
Path: m/2
Public Key: e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434
Peer ID: e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434
Stored: .ftf/spaces/lab/keys/auditor.json

Space: lab
Active Member: auditor
```

### 3. Put source artifact

```bash
printf 'space-test-payload\n' > artifact.bin
ftf put artifact.bin --space lab
```

```text
artifact: 12209025ad3c1f36bec28546ae56b04454557f6273af44f947fb1586e78b6af4e8e1
event:    1220099e988e94a2c738554910733bfa51dcd8906753717154d5916518e3453fa31c
topic:    provenance/main
```

### 4. Append xform

```bash
printf 'space-model-output\n' > model.bin
ftf xform train-model --space lab --input artifact.bin --output model.bin
```

```text
event:    1220b49355452dc76cad093c84a133b60b74abfc17bbc62bc5daece4083d80588835
topic:    provenance/main
output:   12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85
```

Assertions:

- output artifact `B = 12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85` is stored in the space-local CAS
- signed `xform` is appended to `.ftf/spaces/lab/topics/provenance/main.ndjson`
- `author = e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434` matches active member `auditor`

### 5. Append attest note

```bash
ftf attest model.bin --space lab --claim reproduced
```

```text
about:    12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85
claim:    reproduced
event:    1220e1353f4f733a67238906974d4c9d5b13e123c4a92ef361ce8bf208d812ef3e94
topic:    provenance/main
```

Assertions:

- `about = B`
- claim text is preserved as `reproduced`
- note author matches active member `auditor`
- topic is unchanged except append

### 6. Append revoke note

```bash
ftf revoke 1220b49355452dc76cad093c84a133b60b74abfc17bbc62bc5daece4083d80588835 --space lab --reason "bad build"
```

```text
target:   1220b49355452dc76cad093c84a133b60b74abfc17bbc62bc5daece4083d80588835
reason:   bad build
event:    1220b219cde1addd8814d2567d5b5aa62ada2926e1d5f861765509bc29335ed41d98
topic:    provenance/main
```

Assertions:

- `target =` xform event hash
- reason text is preserved as `bad build`
- note author matches active member `auditor`
- revoke is append-only annotation, not deletion

### 7. Set alias

```bash
ftf alias set model/latest 12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85 --space lab
```

```text
id:      model/latest
target:  12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85
event:   1220479ee120fb5662e2adb032acf876a8a173cc868d5f01905364851f3adcf851ea
topic:   alias/main
```

### 8. Trace by alias

```bash
ftf trace --space lab model/latest
```

Trace excerpt:

```ndjson
{"kind":"trace.header","root":"12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85","version":1}
{"h":"12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85","kind":"trace.artifact","role":"root","status":"ok"}
{"h":"12209025ad3c1f36bec28546ae56b04454557f6273af44f947fb1586e78b6af4e8e1","kind":"trace.artifact","role":"dependency","status":"ok"}
{"author":"e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434","etype":"xform","inputs":["12209025ad3c1f36bec28546ae56b04454557f6273af44f947fb1586e78b6af4e8e1"],"kind":"trace.event","mh":"1220b49355452dc76cad093c84a133b60b74abfc17bbc62bc5daece4083d80588835","outputs":["12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85"],"t":2,"tool":"1220c8e0745f9af62284b167d797a738e075c6a4a67fdabf94f41277bc91921c4754"}
{"about":"artifact:12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85","author":"e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434","claim":"reproduced","kind":"trace.note","mh":"1220e1353f4f733a67238906974d4c9d5b13e123c4a92ef361ce8bf208d812ef3e94","note_type":"attest","t":3}
{"about":"event:1220b49355452dc76cad093c84a133b60b74abfc17bbc62bc5daece4083d80588835","author":"e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434","kind":"trace.note","mh":"1220b219cde1addd8814d2567d5b5aa62ada2926e1d5f861765509bc29335ed41d98","note_type":"revoke","reason":"bad build","t":4}
{"from":"artifact:12209025ad3c1f36bec28546ae56b04454557f6273af44f947fb1586e78b6af4e8e1","kind":"trace.edge","rel":"consumed_by","to":"event:1220b49355452dc76cad093c84a133b60b74abfc17bbc62bc5daece4083d80588835"}
{"from":"event:1220b49355452dc76cad093c84a133b60b74abfc17bbc62bc5daece4083d80588835","kind":"trace.edge","rel":"produces","to":"artifact:12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85"}
```

Assertions:

- root output artifact is present and materialized
- dependency artifact is present and materialized
- xform event is present
- `consumed_by` edge is present
- `produces` edge is present
- `trace.note` attest is present
- `trace.note` revoke is present
- attest attaches to root artifact
- revoke attaches to xform event

## Topic Log Excerpts

`provenance/main` excerpt:

```ndjson
{"author":"e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434","body":{"artifact":{"hash":"12209025ad3c1f36bec28546ae56b04454557f6273af44f947fb1586e78b6af4e8e1"},"kind":"put"},"caps":[],"prev":null,"realm":"ftf:lab","sig":"80df607eb5ae72c5e86a55ed85bcff4927a297b45b003d2ddbd7d3ad3dffb0e94da4adf99bde0cdacb4258656cab34d4c79d50b69e84b9725541ab084727fa0e","t":1,"topic":"provenance/main","v":1,"witness":null}
{"author":"e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434","body":{"inputs":["12209025ad3c1f36bec28546ae56b04454557f6273af44f947fb1586e78b6af4e8e1"],"kind":"xform","outputs":["12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85"],"receipt":{"env_hash":"1220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","recipe_hash":"1220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},"tool":{"id":"1220c8e0745f9af62284b167d797a738e075c6a4a67fdabf94f41277bc91921c4754","params_hash":"1220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","version":"train-model"}},"caps":[],"prev":"1220099e988e94a2c738554910733bfa51dcd8906753717154d5916518e3453fa31c","realm":"ftf:lab","sig":"0bf59f1632f7a6407d6a5ddf698bc12e5fd83b1aa88493a6af0db6f59902af5fc822f4d37892ec9180fd59d3899b8a9d1ee50ea72ca3a17d47b67955db1f2800","t":2,"topic":"provenance/main","v":1,"witness":null}
{"author":"e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434","body":{"about":"12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85","claim":"reproduced","evidence":[],"kind":"attest"},"caps":[],"prev":"1220b49355452dc76cad093c84a133b60b74abfc17bbc62bc5daece4083d80588835","realm":"ftf:lab","sig":"2284f0bf1119b8ff65ea7b337378118a35f5b6e08a59e90d6d1139f9d4e32fb2f230158188644b5e3ef45eb9ad6923dc0eb6942536ec4f812d674ddc4d40fe02","t":3,"topic":"provenance/main","v":1,"witness":null}
{"author":"e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434","body":{"kind":"revoke","reason":"bad build","superseded_by":null,"target":"1220b49355452dc76cad093c84a133b60b74abfc17bbc62bc5daece4083d80588835"},"caps":[],"prev":"1220e1353f4f733a67238906974d4c9d5b13e123c4a92ef361ce8bf208d812ef3e94","realm":"ftf:lab","sig":"e150a75eb99b3685fa65ae9129ec9511674cfa2ae5bd382e275e46452e4f44d67c2dc30af4b2b1ac6b941efdd77b39ad9b08600fcc77a64f7e1eb8f86d2b850f","t":4,"topic":"provenance/main","v":1,"witness":null}
```

`alias/main` excerpt:

```ndjson
{"author":"e993733299b0d703d0d31ef885e6874a0eead8b5712501514f8636b3ce62d434","body":{"id":"model/latest","kind":"alias_claim","note":null,"prev_alias_hash":null,"target_hash":"12203ddc17a979b55cefd6973b7af00fae6b97cc0e6964c290834d9a779f1be71a85"},"caps":[],"prev":null,"realm":"ftf:lab","sig":"3a74cfcb5841435e3f52e2c1132fe2c2cca4d274fe8d7ada75fcdd0a61dbdf468f027dba03dad7a91027946eb5bedffcf109f8a53e5ea84a73d622e817fae403","t":1,"topic":"alias/main","v":1,"witness":null}
```

## Proof Receipt

- Smoke script: `bash scripts/smoke-space-new.sh`
- Protocol gate: `bash verify-wire.sh`

Observed result:

```text
[verify-wire] ok wire conformance
```

## Verified Claims

- space-local signing works with active member selection
- alias resolution works inside spaces
- transforms work inside spaces
- attest is a witness/annotation event, not lineage mutation
- revoke is a non-destructive annotation event, not deletion
- trust decisions remain replay-based over append-only history
- wrapper commands preserve the frozen wire layer (`verify-wire.sh` remains green)

## Conclusion

Spaces now support governed local provenance with append-only non-destructive
note semantics:

`put`, `xform`, `attest`, `revoke`, `alias`, `trace`.
