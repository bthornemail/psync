# Federated Handoff Receipt (Latest)

- Date (UTC): 2026-03-06T20:47:00Z
- Repository: `/root/psync`
- Scope: bounded two-space handoff proving locality by default and interoperability by explicit receipt artifact

## Goal

Prove that:

- space-local traces remain local by default
- cross-space relation exists only through an explicit handoff artifact
- no implicit global merge occurs across spaces

This receipt uses only existing local spaces commands. No federation transport, import/export, or hidden cross-space authority is assumed.

## Scenario

### 1. Space `alpha` produces a local artifact and provenance

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

Observed outputs:

```text
Space: alpha
Realm: ftf:alpha
Space ID: 122001be3d117c2b666634d100163136037664b56ac9a8518ba910dac719cc1e935c
Created: .ftf/spaces/alpha

Member: auditor
Path: m/2
Public Key: 941a97b8a17a84f13419b1c0d271e62e454f1e8048a3b04a886a8f88cd8dfb44
Peer ID: 941a97b8a17a84f13419b1c0d271e62e454f1e8048a3b04a886a8f88cd8dfb44
Stored: .ftf/spaces/alpha/keys/auditor.json

artifact: 1220fdf84f7d8f297e4e5435f9b57a2551788cf67495226acf1612935f5858d7c174
event:    1220a5eee4bccfb32c282b58d768b39249e24478a15373f5b446ee9e904a82183b70
topic:    provenance/main

event:    1220a3fd5a2d96e29a6b4bba7966ced84b4fb828943002ced9e9f13e344ee1ee36b9
topic:    provenance/main
output:   12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646

about:    12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646
claim:    produced
event:    12204548954745449155457084e7def65cde65a497f7d8922a410a8718c9c9531913
topic:    provenance/main
```

Bounded identifiers:

- source dataset artifact: `1220fdf84f7d8f297e4e5435f9b57a2551788cf67495226acf1612935f5858d7c174`
- source model artifact: `12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646`
- local xform event: `1220a3fd5a2d96e29a6b4bba7966ced84b4fb828943002ced9e9f13e344ee1ee36b9`
- local attest event: `12204548954745449155457084e7def65cde65a497f7d8922a410a8718c9c9531913`

### 2. Create explicit handoff artifact for `beta`

```bash
cat > handoff.json <<'EOF'
{"from_space":"alpha","artifact":"12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646","xform":"1220a3fd5a2d96e29a6b4bba7966ced84b4fb828943002ced9e9f13e344ee1ee36b9","attest":"12204548954745449155457084e7def65cde65a497f7d8922a410a8718c9c9531913"}
EOF
```

Explicit handoff contents:

```json
{"from_space":"alpha","artifact":"12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646","xform":"1220a3fd5a2d96e29a6b4bba7966ced84b4fb828943002ced9e9f13e344ee1ee36b9","attest":"12204548954745449155457084e7def65cde65a497f7d8922a410a8718c9c9531913"}
```

This artifact is the only explicit cross-space bridge in the scenario.

### 3. Space `beta` consumes only the handoff artifact

```bash
ftf space new beta
ftf identity derive --space beta --role auditor
ftf identity use --space beta --member auditor
ftf put handoff.json --space beta
printf 'beta review\n' > review.bin
ftf xform review-handoff --space beta --input handoff.json --output review.bin
ftf attest review.bin --space beta --claim accepted
```

Observed outputs:

```text
Space: beta
Realm: ftf:beta
Space ID: 1220416a027fc341c82ffd63e25c0fd3e27b8e2622e00b6d8cdef1834e81f58a31c3
Created: .ftf/spaces/beta

Member: auditor
Path: m/2
Public Key: c0f64388e07f5bbb83952ba1223047bbb65c736c7041042745bd9ca91e0f3924
Peer ID: c0f64388e07f5bbb83952ba1223047bbb65c736c7041042745bd9ca91e0f3924
Stored: .ftf/spaces/beta/keys/auditor.json

artifact: 12207bdd37c1bdd6b233efb3cdaf39781795bd3fc0b2aefde0d1a5f26a8603adc844
event:    1220e8e62fe9c298210ece4b06a8f69bbe82e043638bc51fe9d61e0729dfba7c56e7
topic:    provenance/main

event:    12204d865c2f6e462aa261fdba41e1c20f283708df67b9d8be7247f4a4738e5b0fff
topic:    provenance/main
output:   122058df9b27979835dedbeacc84532759f0590bd39dce82ef2ceacee9459528f9a3

about:    122058df9b27979835dedbeacc84532759f0590bd39dce82ef2ceacee9459528f9a3
claim:    accepted
event:    12208fe15288c68efeecd608834aff65b193796a431f0b8ce51aa341a8e33e76631e
topic:    provenance/main
```

Bounded identifiers:

- handoff artifact in `beta`: `12207bdd37c1bdd6b233efb3cdaf39781795bd3fc0b2aefde0d1a5f26a8603adc844`
- review artifact in `beta`: `122058df9b27979835dedbeacc84532759f0590bd39dce82ef2ceacee9459528f9a3`
- local xform event in `beta`: `12204d865c2f6e462aa261fdba41e1c20f283708df67b9d8be7247f4a4738e5b0fff`
- local attest event in `beta`: `12208fe15288c68efeecd608834aff65b193796a431f0b8ce51aa341a8e33e76631e`

## Trace Receipts

### `trace --space alpha model-a.bin`

```ndjson
{"kind":"trace.header","root":"12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646","version":1}
{"h":"12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646","kind":"trace.artifact","role":"root","status":"ok"}
{"h":"1220fdf84f7d8f297e4e5435f9b57a2551788cf67495226acf1612935f5858d7c174","kind":"trace.artifact","role":"dependency","status":"ok"}
{"artifact":"1220fdf84f7d8f297e4e5435f9b57a2551788cf67495226acf1612935f5858d7c174","author":"941a97b8a17a84f13419b1c0d271e62e454f1e8048a3b04a886a8f88cd8dfb44","etype":"put","kind":"trace.event","mh":"1220a5eee4bccfb32c282b58d768b39249e24478a15373f5b446ee9e904a82183b70","t":1}
{"author":"941a97b8a17a84f13419b1c0d271e62e454f1e8048a3b04a886a8f88cd8dfb44","etype":"xform","inputs":["1220fdf84f7d8f297e4e5435f9b57a2551788cf67495226acf1612935f5858d7c174"],"kind":"trace.event","mh":"1220a3fd5a2d96e29a6b4bba7966ced84b4fb828943002ced9e9f13e344ee1ee36b9","outputs":["12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646"],"t":2,"tool":"1220b06b9380fb202211588e4fcdc9751e500903859b832a43f411b27d6e3cc8825e"}
{"about":"artifact:12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646","author":"941a97b8a17a84f13419b1c0d271e62e454f1e8048a3b04a886a8f88cd8dfb44","claim":"produced","kind":"trace.note","mh":"12204548954745449155457084e7def65cde65a497f7d8922a410a8718c9c9531913","note_type":"attest","t":3}
{"from":"artifact:1220fdf84f7d8f297e4e5435f9b57a2551788cf67495226acf1612935f5858d7c174","kind":"trace.edge","rel":"consumed_by","to":"event:1220a3fd5a2d96e29a6b4bba7966ced84b4fb828943002ced9e9f13e344ee1ee36b9"}
{"from":"event:1220a3fd5a2d96e29a6b4bba7966ced84b4fb828943002ced9e9f13e344ee1ee36b9","kind":"trace.edge","rel":"produces","to":"artifact:12205e2991e24b49f388ad640b13cf0a896c2886b681fede588119898598b1f15646"}
{"from":"event:1220a5eee4bccfb32c282b58d768b39249e24478a15373f5b446ee9e904a82183b70","kind":"trace.edge","rel":"produces","to":"artifact:1220fdf84f7d8f297e4e5435f9b57a2551788cf67495226acf1612935f5858d7c174"}
```

### `trace --space beta review.bin`

```ndjson
{"kind":"trace.header","root":"122058df9b27979835dedbeacc84532759f0590bd39dce82ef2ceacee9459528f9a3","version":1}
{"h":"122058df9b27979835dedbeacc84532759f0590bd39dce82ef2ceacee9459528f9a3","kind":"trace.artifact","role":"root","status":"ok"}
{"h":"12207bdd37c1bdd6b233efb3cdaf39781795bd3fc0b2aefde0d1a5f26a8603adc844","kind":"trace.artifact","role":"dependency","status":"ok"}
{"artifact":"12207bdd37c1bdd6b233efb3cdaf39781795bd3fc0b2aefde0d1a5f26a8603adc844","author":"c0f64388e07f5bbb83952ba1223047bbb65c736c7041042745bd9ca91e0f3924","etype":"put","kind":"trace.event","mh":"1220e8e62fe9c298210ece4b06a8f69bbe82e043638bc51fe9d61e0729dfba7c56e7","t":1}
{"author":"c0f64388e07f5bbb83952ba1223047bbb65c736c7041042745bd9ca91e0f3924","etype":"xform","inputs":["12207bdd37c1bdd6b233efb3cdaf39781795bd3fc0b2aefde0d1a5f26a8603adc844"],"kind":"trace.event","mh":"12204d865c2f6e462aa261fdba41e1c20f283708df67b9d8be7247f4a4738e5b0fff","outputs":["122058df9b27979835dedbeacc84532759f0590bd39dce82ef2ceacee9459528f9a3"],"t":2,"tool":"1220103b06c029f6e04a893d08bcea48150a1321c26959154044a465addc4fc1be14"}
{"about":"artifact:122058df9b27979835dedbeacc84532759f0590bd39dce82ef2ceacee9459528f9a3","author":"c0f64388e07f5bbb83952ba1223047bbb65c736c7041042745bd9ca91e0f3924","claim":"accepted","kind":"trace.note","mh":"12208fe15288c68efeecd608834aff65b193796a431f0b8ce51aa341a8e33e76631e","note_type":"attest","t":3}
{"from":"artifact:12207bdd37c1bdd6b233efb3cdaf39781795bd3fc0b2aefde0d1a5f26a8603adc844","kind":"trace.edge","rel":"consumed_by","to":"event:12204d865c2f6e462aa261fdba41e1c20f283708df67b9d8be7247f4a4738e5b0fff"}
{"from":"event:12204d865c2f6e462aa261fdba41e1c20f283708df67b9d8be7247f4a4738e5b0fff","kind":"trace.edge","rel":"produces","to":"artifact:122058df9b27979835dedbeacc84532759f0590bd39dce82ef2ceacee9459528f9a3"}
{"from":"event:1220e8e62fe9c298210ece4b06a8f69bbe82e043638bc51fe9d61e0729dfba7c56e7","kind":"trace.edge","rel":"produces","to":"artifact:12207bdd37c1bdd6b233efb3cdaf39781795bd3fc0b2aefde0d1a5f26a8603adc844"}
```

## Locality Checks

Observed absence/presence checks:

```text
alpha_has_beta_review=no
beta_has_alpha_model=no
beta_has_handoff=yes
```

Interpretation:

- `trace --space alpha` does not show `beta`'s review artifact
- `trace --space beta` does not implicitly traverse into `alpha`'s model artifact graph
- `trace --space beta` does show the explicit handoff artifact that was locally stored in `beta`

## Proof Receipt

- Bounded two-space local run in a fresh temp workspace
- Baseline protocol gate: `bash verify-wire.sh`

Observed protocol anchor:

```text
[verify-wire] ok wire conformance
```

## Verified Claims

- locality is the default trace law for spaces
- explicit handoff artifacts are sufficient to express cross-space reference
- interoperability occurs by content-addressed receipt, not hidden topic merge
- no implicit foreign authority or global replay view is introduced
- existing wire and conformance surface remains unchanged

## Conclusion

Federated handoff is already representable at the proof level without adding transport machinery:

- space `alpha` keeps its local provenance
- space `beta` keeps its local provenance
- the only cross-space bridge is the explicit handoff artifact

This is the bounded federation law:

- locality by default
- interoperability by explicit receipt
- no hidden global merge
