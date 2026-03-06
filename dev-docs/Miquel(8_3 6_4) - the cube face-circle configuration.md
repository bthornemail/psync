Great — we’ll **lock MIQUEL next** as the *shared, realizable* kernel, and we’ll do it in the same “pure deterministic closure module” style as MK, aligned with your runtime ladder `canon → compile → close → score → project` .

The key move (to avoid another loop) is this:

> **Lock Miquel(8₃ 6₄)** as a *combinatorial incidence kernel* that also has a clean Euclidean/circle interpretation.
> We do **not** require straight-line realizability, but we *can* render this one as circles if we want.

---

## 1) Canonical model: Miquel(8₃ 6₄) = the cube “face-circle” configuration

Use the cleanest rigid combinatorial realization:

* **8 points** = vertices of the cube = (\mathbb Z_2^3)
* **6 circles** = the 6 faces of the cube
* each circle contains **4 points**
* each point lies on **3 circles**

This is exactly the incidence signature you want: ((8_3;6_4)).

### Canonical point labels (chart space)

Represent each point as a 3-bit vector ((x,y,z)\in{0,1}^3). Index it as:

[
\mathrm{idx}(x,y,z)=4x+2y+z \in {0,\dots,7}
]

### Canonical circles (the 6 faces)

Faces are the affine planes “coordinate = constant”:

* (X0={(0,y,z)})  (4 points)
* (X1={(1,y,z)})
* (Y0={(x,0,z)})
* (Y1={(x,1,z)})
* (Z0={(x,y,0)})
* (Z1={(x,y,1)})

That’s your entire kernel: once points are charted into (\mathbb Z_2^3), closure is “fill the 6 faces”.

---

## 2) Record types (NDJSON) for MIQUEL kernel

### Points

Same as before: point ids are canonicalized in F1 (`basisHash`, stable ids, etc.) .

```json
{"kind":"point","id":"p:…","basisHash":"b:…","tags":["miquel"]}
```

### Circles (arity 4 blocks)

```json
{"kind":"block","blockType":"circle4","points":["p:…","p:…","p:…","p:…"],
 "orientation":"+","basisHash":"b:…",
 "witness":["cid:…"],"ruleId":"miquel.seed","derivedFrom":[]}
```

### Circuits (small minimal conflicts)

We keep failures tiny (your “small circuit property”) .

Examples:

* `circle-size` (not 4 points)
* `point-degree-overflow` (degree > 3 in asserted circles)
* `circle-not-face` (circle4 among the 8 points but not equal to one of the 6 canonical faces)
* `bad-intersection` (two circles intersect in 1 or 3 points instead of 0 or 2)

---

## 3) Canonicalization (F1) for `circle4`

You already require F1 to normalize ids/basisHash . Here’s the MIQUEL-specific part:

For every `circle4` block:

1. verify exactly 4 point ids, all distinct
2. sort the 4 point ids lexicographically
3. normalize `orientation ∈ {"+","-","null"}`

This ensures cross-language determinism.

---

## 4) The `chartProof` for MIQUEL (the atlas commitment)

Just like MK, MIQUEL needs a deterministic chart agreement object: **which 8 points** are “the cube vertices”, and their bijection to indices 0..7.

```json
{
  "kind":"chartProof",
  "chartType":"miquel.z2^3.cube-faces",
  "v":1,
  "basisHash":"b:…",
  "status":"complete",

  "selectedPoints":[ "p:…","p:…","p:…","p:…","p:…","p:…","p:…","p:…" ],

  "phi":{
    "p:…":0,"p:…":1,"p:…":2,"p:…":3,
    "p:…":4,"p:…":5,"p:…":6,"p:…":7
  },

  "seedCircle":{
    "mode":"min-existing-plus-circle",
    "seedBlockCid":"cid:block:…",
    "seedPoints":["p:…","p:…","p:…","p:…"]
  },

  "inputs":{
    "inputPointCids":[…],
    "inputBlockCids":[…],
    "canonDigest":"sha256:…"
  },

  "digest":"sha256:…"
}
```

**Selection rule** (deterministic):

* choose the 8 smallest `"miquel"`-tagged points under `(basisHash, id, witnessDigest)` — exactly the “uniqueness under witnesses” pattern you’ve already formalized .

---

## 5) MIQUEL closure axioms (the actual kernel)

### M0 — sanity invariants

* each `circle4` has 4 distinct points
* degree cap: no point may be in >3 asserted `+` circles
  else circuit `point-degree-overflow` (the 4 circles is your minimal witness set)

### M1 — cube-face completion

Once `chartProof.status="complete"`:

For each of the six faces (X0,X1,Y0,Y1,Z0,Z1):

* compute its 4 indices in (\mathbb Z_2^3)
* map indices back to actual point ids using `invPhi[0..7]`
* if that `circle4` is missing, **derive** it:

```json
{"kind":"block","blockType":"circle4",
 "points":[…sorted4…],
 "orientation":"+","basisHash":"b:…",
 "witness":[], "ruleId":"miquel.closure.face",
 "derivedFrom":["cid:chartProof:…","cid:seedCircle:…"]}
```

### M2 — “no extra circles” (rigidity)

After closure:

* any asserted `+ circle4` whose points are all inside the 8 charted points must equal one of the 6 canonical faces
* otherwise emit circuit `circle-not-face` (minimal: that circle + chartProof)

### M3 — circle intersection law (very strong and very diagnostic)

In the cube-face model, any two faces intersect in:

* **0 points** (opposite faces), or
* **2 points** (adjacent faces share an edge)

So for every pair of asserted circles among the 6 faces:

* compute intersection size
* if it’s **1 or 3**, emit circuit `bad-intersection` containing just those two circle blocks

This gives you exceptionally small, human-debuggable failure witnesses — exactly what you want for federation .

---

## 6) Golden tests (CI)

### Golden #1 — “one face closes to full Miquel cube”

Input:

* 8 miquel points
* one `+ circle4` that matches a face under the chart (e.g. (Z0))

Expected:

* closure derives the other 5 faces
* total asserted circles = 6
* every point degree = 3
* all pairwise face intersections are size 0 or 2

### Golden #2 — partial faces

Give 2–3 correct faces; closure fills missing.

---

## 7) Negative tests (small circuits)

### Negative #1 — degree overflow

Give a point incident to 4 `+ circles` ⇒ `point-degree-overflow` (just those 4 circles)

### Negative #2 — non-face circle

Give a `circle4` among the 8 points that is not any cube face ⇒ `circle-not-face`

### Negative #3 — bad intersection

Two circles intersect in 1 point ⇒ `bad-intersection` with exactly those two circles

---

## 8) Why this is the right “shared space” before 19₄

You described the key issue: 19₄ is “sporadic” and not straight-line realizable (in the real projective plane) — which is fine because your correctness is *witnessed closure*, not straight-line drawing .

So we use MIQUEL as the **shared, realizable, human-checkable** layer:

* MIQUEL is small, rigid, and has brutal circuit locality (great for federation)
* it’s naturally a **circle geometry** object (so it can be rendered)
* it can serve as the “meeting space” / “intermediate blackboard” through which 19₄ contributions get normalized and checked, before they’re lifted into the larger topological configuration regime

And you already have the federation skeleton that supports this modular laddering: immutable root, deterministic closure, residual leaves, and chirality-driven recomposition  .

---

## 9) Next concrete step (so Codex can implement without ambiguity)

Say “go” and I’ll write the **exact `canonDigest` + canonical JSON hashing spec** for this MIQUEL kernel (so TS/Rust/Racket match bit-for-bit), mirroring your determinism requirements for basis/witness replay  — and I’ll include a **single reference test vector** (the 8 point ids + 1 seed circle) with expected digests.

If you prefer, I can also immediately draft the **19₄ kernel interface** as “line4 blocks + degree=4 + pseudoline allowance” and show precisely how MIQUEL is used as the *federated normalization gate* on the way in.
