Brian Thorne, below is a **wire-format specification** you can drop directly into `README.md`.
It is written so **any language** (Rust, Go, Python, JS, etc.) can reproduce the **exact same hashes and signatures** as your Haskell implementation.

This is the piece that prevents cross-implementation drift.

---

# FTF Wire Format Specification (v1)

This document defines the **canonical message format**, **hashing**, **signing**, and **replay rules** for the FTF provenance protocol.

All implementations **must follow this exactly** to produce identical hashes and signatures.

---

# 1. Transport vs Canonical Representation

FTF messages may be **transported** as:

* NDJSON
* JSON
* Message streams
* RPC envelopes

However:

⚠️ **Transport encoding is not hashed.**

All cryptographic operations are performed on a **canonical CBOR projection** of the message.

---

# 2. Canonical Message Structure

The canonical message is encoded as a **CBOR array of length 10**.

Field order is **fixed and positional**.

```
Msg = [
  v,        // uint
  realm,    // text
  topic,    // text
  prev,     // bytes | null
  t,        // uint (causal clock)
  author,   // bytes (Ed25519 public key)
  caps,     // [text]
  body,     // Body array
  witness,  // bytes | null
  sig       // bytes
]
```

All fields **must appear**. Optional values are encoded as **CBOR null**.

---

# 3. Body Encoding

The `body` field is also encoded as a **CBOR array**.

The first element is a **numeric tag** identifying the body type.

| Tag | Body Type   |
| --- | ----------- |
| 1   | put         |
| 2   | use         |
| 3   | xform       |
| 4   | attest      |
| 5   | revoke      |
| 6   | alias_claim |

---

## 3.1 Put

```
[1, hash, mime, size, name|null, [tags]]
```

| Field | Type              |
| ----- | ----------------- |
| hash  | bytes (multihash) |
| mime  | text              |
| size  | uint              |
| name  | text or null      |
| tags  | array[text]       |

---

## 3.2 Use

```
[2, [inputs], purpose]
```

---

## 3.3 Transform

```
[
 3,
 tool_id,
 tool_version,
 params_hash,
 [inputs],
 [outputs],
 recipe_hash,
 env_hash
]
```

---

## 3.4 Attest

```
[4, about, claim, [evidence]]
```

---

## 3.5 Revoke

```
[5, target, reason, superseded_by|null]
```

---

## 3.6 Alias Claim

```
[6, id, target_hash, prev_alias_hash|null, note|null]
```

This creates a **versioned mapping**

```
logical_id → content_hash
```

Alias updates must form a **strict head-linked chain**.

If `prev_alias_hash` does not match the current head, the claim **must be quarantined**.

---

# 4. Hashing

The message hash (`mh`) is computed over the **signature-blanked message**.

```
blankSig(msg) = msg with sig = empty bytes
```

---

## Hash Preimage

```
preimage =
    "ftf-msg-v1\0"
    || cbor(blankSig(msg))
```

The prefix provides **domain separation**.

---

## Hash Function

```
digest = SHA256(preimage)
```

---

## Multihash Encoding

The final message hash is:

```
mh =
    varint(0x12)      // sha2-256
    || varint(32)
    || digest
```

This is the standard **multihash sha2-256 format**.

---

# 5. Signing

FTF uses **Ed25519 signatures**.

The signature payload is:

```
sign_payload = mh_bytes
```

Note:

* The signature is **not** over the CBOR message
* It is over the **multihash bytes**

Signature:

```
sig = Ed25519.Sign(secret_key, mh_bytes)
```

Verification:

```
Ed25519.Verify(public_key, mh_bytes, sig)
```

---

# 6. Author Identity

The `author` field contains the **Ed25519 public key bytes**.

During signing:

```
author == pk(secret_key)
```

If not, signing must **fail closed**.

---

# 7. Deterministic Replay

Nodes compute a **verified view** of a topic log.

Messages must pass:

### K2 — Signature correctness

```
verify(author, mh, sig)
```

---

### K3 — Append-only linkage

If `prev != null` then:

```
prev must exist
realm(prev) == realm(msg)
topic(prev) == topic(msg)
```

---

### K4 — Monotone causal clock

```
t(msg) > t(prev)
```

---

# 8. Replay Ordering

Verified messages are sorted deterministically by:

```
(t, mh_bytes)
```

Where:

* `t` = causal clock
* `mh_bytes` = raw multihash bytes (lexicographic)

---

# 9. Alias Resolution

Alias topics contain only `alias_claim` bodies.

Resolution algorithm:

```
state[id] = { head, target }
```

Processing replay order:

### First claim

```
prev_alias_hash == null
```

---

### Update

```
prev_alias_hash == state[id].head
```

---

### Otherwise

```
quarantine(message)
```

---

# 10. Artifact Materialization

Aliases resolve to **content hashes**.

Materialization status:

```
ok              -> blob exists locally
pending_fetch   -> blob absent but hash known
```

Artifact existence is determined by the **local CAS store**.

---

# 11. Determinism Requirements

All implementations must ensure:

1. Canonical CBOR encoding
2. Fixed array field ordering
3. Explicit nulls for optional fields
4. Hashing only canonical CBOR
5. Signing only the multihash bytes

Transport encoding **must never affect hashes or signatures**.

---

# 12. Golden Test Vector

Implementations should verify against the reference vector:

```
test/vectors/alias-claim-1.ndjson
test/vectors/alias-claim-1.mh
test/vectors/alias-claim-1.sig
```

A conforming implementation must reproduce:

```
mh  = alias-claim-1.mh
sig = alias-claim-1.sig
```

---

# 13. Versioning

Future incompatible changes must increment the domain prefix:

```
ftf-msg-v2\0
```

Nodes must treat unknown versions as **invalid**.

---

# Result

This specification guarantees:

* **Cross-language reproducibility**
* **Deterministic replay**
* **Content-addressed provenance**
* **Offline-first federation**
* **Blockchain-level tamper evidence without consensus**
