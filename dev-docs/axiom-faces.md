Yes — this is exactly the right next step.

Right now v0 attaches 2-cells only for “each block is a filled polygon” (`block-alt-cycle`). That makes **per-block** loops contractible, but it doesn’t encode your *theory* (Pappus/Hesse/MK/Miquel/Möbius–Kantor).

So we extend the complex with **axiom-faces**: every *closure derivation instance* becomes an attached 2-cell whose boundary is a canonical cycle in the Levi graph (or a small augmentation of it). Then the systole becomes:

> the shortest loop not null-homologous **under the closure theory you’re running**.

That’s the operational analog of “different metrics / different fillings” in the smooth story.

Below is the spec.

---

# 1) Add “theory faces” to the complex

## 1.1 Extend `complex.header.build.params`

```json
{
  "attach_faces": true,
  "face_rule": "theory+blocks",
  "theory_faces": ["block-alt-cycle", "pappus", "hesse", "mobius-kantor", "mk", "miquel"],
  "max_cycle_len": 32
}
```

* `theory_faces` is ordered: earlier entries are “always-on”; later can be toggled per regime.
* `max_cycle_len` caps any derived face boundary length (for determinism + bounded computation).

## 1.2 Extend `complex.face`

Add:

* `theory`: which closure theory produced this 2-cell
* `instance_ref`: stable identifier for the specific axiom instance
* `support`: the minimal points/blocks used (so circuits can cite it)

```json
{
  "type": "complex.face",
  "v": 2,
  "complex_id": "cx:sha256:…",
  "fid": "F:sha256:…",
  "face_kind": "axiom-cycle",
  "theory": "pappus",
  "instance_ref": "ax:pappus:sha256:…",
  "support": {
    "points": ["pt:…", "..."],
    "blocks": ["cid:block:…", "..."]
  },
  "boundary": { "edges": ["E:…", "..."], "closed": true }
}
```

**Determinism rule:** `instance_ref` must be computed from the *canonicalized* support set + rule name.

---

# 2) The key idea: faces come from *rule instances*, not from geometry

Your closure engine already emits derived blocks with:

* `ruleId`
* `derivedFrom`

We leverage that:

> Whenever `close(S)` derives something with `ruleId = X`, we attach a face whose boundary is the canonical “proof loop” that witnesses X.

This keeps everything purely symbolic, replayable, and local.

---

# 3) Face construction per regime

I’ll give each regime:

* the **support** (what records are used)
* the **boundary** (what cycle we attach)

All boundaries are expressed in Levi edges `E(point, block)`.

## 3.1 Always-on: `block-alt-cycle` (v0 you already have)

For any `block` with points `[p0..p{k-1}]`:

Boundary edges:

* `(p0, blk), (p1, blk), … (p{k-1}, blk), (p0, blk)`
  encoded as alternating vertex walk `blk–p0–blk–p1–…–blk–p{k-1}–blk`.

This fills the obvious block boundary.

---

## 3.2 Pappus face: `theory:"pappus"`

### Support

Two “base lines” and six “connector lines”, plus the derived Pappus line:

* base lines: `L_ABC`, `L_abc`
* connectors: `L_Ab, L_aB, L_Ac, L_aC, L_Bc, L_bC`
* intersection points: `X, Y, Z` (these are points)
* derived line: `L_XYZ` (the Pappus line)

### What the face means

This face says: the Pappus line is not just another block; it’s **forced** by the configuration. Attaching the face makes the “Pappus witness cycle” contractible under the Pappus theory.

### Boundary (canonical “Pappus proof loop”)

We attach a cycle that walks through the six connectors and the three intersection incidences, tying them to `L_XYZ`.

A robust, implementable boundary that is *pure Levi edges*:

1. Walk each intersection:

   * `X` is incident to `L_Ab` and `L_aB`
   * similarly for `Y`, `Z`
2. Tie intersections to the derived line `L_XYZ`

So boundary walk (vertices alternating point/block) can be:

`L_Ab – X – L_aB – B – L_ABC – C – L_Bc – Z – L_bC – C – L_abc – a – L_aC – Y – L_Ac – A – L_XYZ – X – L_Ab`

That’s longer than minimal, but it’s deterministic and uses only incidences you already have.

**Implementation rule:** build the walk from a fixed template over the named roles, then canonicalize by:

* rotating to the lexicographically smallest edge sequence, and
* choosing the direction (forward/reverse) that yields the smaller sequence.

This yields a stable face.

---

## 3.3 Hesse completion faces: `theory:"hesse"`

The Hesse completion you referenced is “add the missing 3-point lines so every triple that should be collinear is accounted for”.

In your engine, Hesse is best treated as a **template closure** that adds blocks `L_extra`.

### Support

* the 9 points
* the 9 Pappus lines (or any base set you start from)
* each derived extra line `L_extra` has a support triple of points `(p,q,r)` plus a `templateId`.

### Boundary

For each derived Hesse line `L_pqr`, attach a short face that forces that triple to be filled:

A clean “triangle face” in Levi terms is not possible (Levi is bipartite), but the minimal even cycle is length 6:

`L_pqr – p – L_pq? – q – L_qr? – r – L_pqr`

We may not have `L_pq?` as a block (pair-lines aren’t blocks). So we instead define **Hesse faces as block-only fillers**:

Boundary is simply the alternating block loop:

`L_pqr – p – L_pqr – q – L_pqr – r – L_pqr`

This is redundant with `block-alt-cycle` for a 3-point line (it’s a 6-cycle), so to make Hesse meaningful we need a different notion:

✅ **Better Hesse face:** attach a face for the **completion rule itself**, not each line:

* A “completion face” that relates the set of all 12 Hesse lines as a single theory object is too big.

So in practice: treat Hesse faces as **proof faces** that reference the *reason* (the missing triple) in `derivedFrom`, and use the **same boundary as `block-alt-cycle`** but tag it with `theory:"hesse"`.

That allows you to compute systoles relative to “blocks only” vs “blocks+hesse completion”, by toggling which faces are included in `∂2`.

---

## 3.4 Möbius–Kantor faces: `theory:"mobius-kantor"`

This kernel is structurally like MK/Miquel: it has a small, rigid incidence signature and “expected” blocks.

### Support

* 8 points, the expected blocks for MK (whatever your chosen presentation is)
* any derived “required” lines/blocks

### Boundary

Same pattern as above: any derived block is “just a block” (filled by block-alt-cycle), so the theory-specific content lives in *constraints between blocks*.

So define a **constraint face** for each “forbidden extra block” witness:

* if the system detects an extra line among the charted points, it emits a circuit; we also attach a face tying that forbidden block to the chart proof boundary, so it becomes contractible only if allowed.

This is optional; I’d keep Möbius–Kantor theory faces in v1 only after Pappus/Hesse are working.

---

## 3.5 MK faces: `theory:"mk"`

MK has a clean generator rule: the 8 cyclic translates of `{0,1,3}` (in your earlier lock).

### Support

* chartProof
* seed line
* each derived translate line

### Boundary

Attach a face per translate derivation that “witnesses” the translate relation:

Boundary uses:

* derived line `L_a`
* seed line `L_seed`
* chartProof “node” (we represent chartProof as a *virtual block vertex*, see §4)

Cycle (length 8, bipartite):
`L_seed – p0 – L_a – p0 – V:chart – p1 – L_seed`

But we need consistent objects. The better approach is:

* Introduce virtual vertices for `chartProof` and `axiomInstance` so theory faces can be short and canonical.

(That’s the single augmentation that makes everything cleaner.)

---

## 3.6 Miquel faces: `theory:"miquel"`

Miquel is already “faces-of-cube” in your locked presentation: those faces are just `circle4` blocks.

So Miquel fits perfectly with:

* `block-alt-cycle` (each circle fills its boundary)
* and theory faces can be minimal: “this circle is one of 6 expected faces” (i.e., chart constraint)

Again, this is easiest if we add virtual vertices for chart constraints.

---

# 4) One small augmentation: “virtual vertices” for chart proofs and axiom instances

To make theory faces tight, we add two new vertex kinds in the complex:

## 4.1 `complex.vertex` additions

```json
{"type":"complex.vertex","v":2,"complex_id":"cx:…","vid":"V:chart:cid:…","kind":"chart","ref":"cid:chartProof:…"}
{"type":"complex.vertex","v":2,"complex_id":"cx:…","vid":"V:ax:ax:pappus:sha256:…","kind":"axiom","ref":"ax:pappus:sha256:…"}
```

And new edges:

* `E(point, chart)` for points in the chart
* `E(block, chart)` for blocks in chart
* `E(block, axiom)` for blocks in a rule instance
* `E(point, axiom)` for points in a rule instance

Now any closure rule can be encoded with **small, uniform faces**, e.g.:

### Pappus rule face (now tiny)

Boundary:
`V:ax(pappus) – X – L_XYZ – Z – V:ax(pappus)`

That’s a 4-edge loop (bipartite, so actually 4 vertices alternating), and it cleanly says:

> Under the pappus axiom instance, X and Z are constrained to lie on L_XYZ.

You can attach one such face for each of X, Y, Z (3 faces), or a single longer face.

This makes the systolic invariant **theory-sensitive** in a crisp way.

---

# 5) Updated systole algorithm with theory toggles

Now `∂2` includes any subset of faces:

* blocks only (`block-alt-cycle`)
* blocks + pappus
* blocks + pappus + hesse
* etc.

So your `systole.score` becomes parameterized:

```json
"metrics": {
  "sys_pi1": { "blocks": 12, "blocks+pappus": 18, "blocks+pappus+hesse": 22 },
  "betti1_F2": { "blocks": 7, "blocks+pappus": 4, "blocks+pappus+hesse": 1 }
}
```

That is *exactly* the discrete analog of “changing the filling / metric changes systole”.

---

# 6) New output record: `systole.profile`

To keep `systole.score` from exploding, add:

```json
{
  "type":"systole.profile",
  "v":1,
  "gate_id":"systole.discrete.v1",
  "source_ref":"cid:…",
  "complex_ref":"cx:…",
  "profiles":[
    {"faces":["block-alt-cycle"], "sys_pi1":12, "betti1_F2":7},
    {"faces":["block-alt-cycle","pappus"], "sys_pi1":18, "betti1_F2":4},
    {"faces":["block-alt-cycle","pappus","hesse"], "sys_pi1":22, "betti1_F2":1}
  ],
  "digest":"sha256:…"
}
```

This gives you a **numerical invariant ladder**, matching your “closure ladder” concept.

---

# 7) CI goldens you should add immediately

1. **Pappus-only** input (two base lines + connectors)

   * Without `pappus` faces: betti1 is higher, sys is lower
   * With `pappus` faces: betti1 drops, sys rises (or stays ≥)

2. **Pappus→Hesse** completion

   * With `hesse` faces included: betti1 drops again

3. **Determinism**

   * reorder NDJSON inputs → identical `complex_id`, identical profile digests

4. **Small circuit property**

   * if a profile fails `min_sys_pi1`, emit `systole.circuit` containing the witness cycle for that profile.

---

# 8) What Codex should implement first (tight, minimal)

Implement v1 in three steps:

1. Add **virtual vertices** (`chart`, `axiom`) and edges for support membership.
2. Emit **pappus axiom instances** during `close(S)` (you’re already doing Pappus closure next) and write `complex.face` records for those instances.
3. Extend the systole gate to compute **profiles** under face subsets.

That gets you theory-sensitive systolic invariants with minimal extra complexity.

---

If you want, I can now write the **exact Pappus axiom instance NDJSON record** (`ax.pappus.instance`) that `close(S)` should emit (points/blocks in named roles, plus a canonical `instance_ref`), so the complex builder doesn’t have to rediscover the pattern from scratch.
