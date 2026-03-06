Locked. Here is the **Danzer kernel interface** in the same style as the 19₄ spec.

---

# Danzer Kernel v0

## 1) Canonical object

Use the ground set:

[
U = {0,1,2,3,4,5,6}
]

Define:

* **Points** = all 3-subsets of (U)
* **Lines** = all 4-subsets of (U)
* **Incidence** = inclusion

So:

* number of points = (\binom{7}{3}=35)
* number of lines = (\binom{7}{4}=35)
* each point lies on 4 lines
* each line contains 4 points

This gives the canonical self-dual **((35_4))** Danzer configuration.

---

## 2) Canonical naming

## 2.1 Point IDs

Represent each 3-subset in sorted order.

Examples:

* `{0,1,2}` → `p:danzer:012`
* `{0,1,3}` → `p:danzer:013`
* `{4,5,6}` → `p:danzer:456`

## 2.2 Line IDs

Represent each 4-subset in sorted order.

Examples:

* `{0,1,2,3}` → `l:danzer:0123`
* `{0,1,2,4}` → `l:danzer:0124`
* `{3,4,5,6}` → `l:danzer:3456`

These names are fully deterministic and human-readable.

---

## 3) NDJSON schema

## 3.1 Point record

```json
{
  "kind": "point",
  "id": "p:danzer:012",
  "basisHash": "b:sha256:...",
  "tags": ["danzer35_4"],
  "witness": []
}
```

## 3.2 Line record

```json
{
  "kind": "block",
  "blockType": "line4",
  "id": "l:danzer:0123",
  "points": [
    "p:danzer:012",
    "p:danzer:013",
    "p:danzer:023",
    "p:danzer:123"
  ],
  "orientation": "+",
  "basisHash": "b:sha256:...",
  "ruleId": "danzer.generator",
  "derivedFrom": []
}
```

Important:

* a line record stores the **4 point IDs incident to that 4-subset**
* not the raw symbols `0,1,2,3`
* that keeps the kernel purely as a point-line incidence structure

---

## 4) Generator contract

No seed table is needed. This kernel should be generated, not hand-entered.

## 4.1 Transform ID

```text
cfg.danzer35_4.v0.generate
```

## 4.2 Generator algorithm

1. Enumerate all 3-subsets of `U` in lexicographic order.
2. Emit one point record per 3-subset.
3. Enumerate all 4-subsets of `U` in lexicographic order.
4. For each 4-subset `L = {a,b,c,d}`, emit the line with incident points:

   * `{a,b,c}`
   * `{a,b,d}`
   * `{a,c,d}`
   * `{b,c,d}`

This is the entire kernel.

---

## 5) Canonical ordering

Lexicographic order on subsets:

For tuples of equal length, compare entrywise.

Examples:

```text
012 < 013 < 014 < 015 < 016 < 023 < ...
0123 < 0124 < 0125 < ... < 3456
```

This determines:

* point emission order
* line emission order
* canonical digest order

---

## 6) Closure model

Danzer is best treated as a **generated closed kernel**, not an inferential closure like Pappus.

So:

* `generate()` creates the full closed structure
* `close()` for Danzer mostly verifies integrity and emits small circuits on corruption

### Closure transform

```text
cfg.danzer35_4.v0.close
```

### Behavior

* accept canonical generated state
* reject malformed or mutated states
* optionally restore missing derived lines if running in repair mode

Recommended default:

* **verification-only**
* do not silently repair unless explicitly requested

---

## 7) Invariants and gates

## 7.1 Hard invariants

These must hold.

### I1 — point count

Exactly 35 points.

### I2 — line count

Exactly 35 line4 blocks.

### I3 — line arity

Each line has exactly 4 distinct point IDs.

### I4 — point degree

Each point lies on exactly 4 lines.

### I5 — incidence correctness

A line `l:danzer:abcd` must contain exactly the 4 points:

* `p:danzer:abc`
* `p:danzer:abd`
* `p:danzer:acd`
* `p:danzer:bcd`

### I6 — no extra incidences

No point may appear on a line unless its 3-subset is contained in the line’s 4-subset.

---

## 7.2 Small circuits

### Circuit: `danzer.line-arity`

A line has duplicate or wrong number of points.

### Circuit: `danzer.line-membership`

A line contains a point not corresponding to one of its 4 constituent 3-subsets.

### Circuit: `danzer.point-degree`

A point has degree ≠ 4.

### Circuit: `danzer.count-mismatch`

Point or line count differs from 35.

### Circuit: `danzer.duplicate-line`

Two lines have the same 4-subset label or same support set.

### Circuit: `danzer.duplicate-point`

Two points represent the same 3-subset.

Each circuit should include:

* offending record IDs
* minimal support subset
* basisHash
* digest

---

## 8) Chart proof

Danzer is canonical enough that the chart is trivial, but for consistency with your other kernels:

```json
{
  "kind": "chartProof",
  "chartType": "danzer35_4.subsets-of-7",
  "v": 1,
  "basisHash": "b:sha256:...",
  "status": "complete",
  "groundSet": [0,1,2,3,4,5,6],
  "pointIds": [
    "p:danzer:012",
    "p:danzer:013",
    "...",
    "p:danzer:456"
  ],
  "lineIds": [
    "l:danzer:0123",
    "l:danzer:0124",
    "...",
    "l:danzer:3456"
  ],
  "generator": {
    "points": "all 3-subsets",
    "lines": "all 4-subsets",
    "incidence": "subset inclusion"
  },
  "digest": "sha256:..."
}
```

---

## 9) Levi graph view

This is important because it plugs directly into your systolic gate.

### Vertices

* 35 point-vertices
* 35 line-vertices

### Edges

* one edge for each inclusion (3\text{-subset} \subset 4\text{-subset})

Total:
[
35 \cdot 4 = 140
]
incidence edges.

So Levi graph has:

* 70 vertices
* 140 edges
* bipartite
* 4-regular

This is the middle-layer graph for (Q_7) between weights 3 and 4.

That is a big reason this kernel is so good.

---

## 10) Theory-face integration

Danzer works immediately with the discrete systolic gate.

## 10.1 Block faces

Each line4 yields a `block-alt-cycle` face.

Since each line has 4 points, each face boundary is an 8-cycle in the Levi graph.

## 10.2 Optional theory faces

Later you can add:

* Fano subconfiguration faces
* Pappus-derived faces on selected slices
* duality faces linking complementary subsets

But v0 only needs block faces.

---

## 11) 240-ring lens embedding

Danzer has 35 points, so it embeds nicely as a lens over the 240 ring.

## 11.1 Point embedding

Use a simple injective arithmetic map:

[
\mu(i) = (7i)\bmod 240,\quad i=0,\dots,34
]

Since (\gcd(7,240)=1), this is injective on the first 35 values.

Assign Danzer points in lexicographic order to indices `0..34`, then map through `μ`.

Example first few:

* `p:danzer:012` → index 0 → LED 0
* `p:danzer:013` → index 1 → LED 7
* `p:danzer:014` → index 2 → LED 14
* ...
* point #34 → LED `(7*34) mod 240 = 238`

## 11.2 Lens artifact

```json
{
  "type": "wave30.lens_danzer35_4",
  "v": 1,
  "lens_id": "lens:danzer35_4:sha256:...",
  "point_order": [
    "p:danzer:012",
    "p:danzer:013",
    "...",
    "p:danzer:456"
  ],
  "ring_map": {
    "p:danzer:012": 0,
    "p:danzer:013": 7,
    "...": 238
  },
  "digest": "sha256:..."
}
```

## 11.3 Render behavior

* render the 35 point LEDs
* when a line is active, highlight its 4 points
* optionally draw all 6 pair chords among the 4 points, or deterministic pairings:

  * smallest↔largest
  * 2nd↔3rd

This is advisory only, not canonical truth.

---

## 12) Golden fixtures

## 12.1 Golden: exact generator output

Input:

* no points
* no lines
* call `cfg.danzer35_4.v0.generate`

Expected:

* 35 point records
* 35 line records
* no circuits

## 12.2 Golden: closure verify

Input:

* full generated kernel

Expected:

* passes invariants
* point degree = 4 everywhere
* line arity = 4 everywhere
* no circuits

---

## 13) Must-reject fixtures

## 13.1 Wrong line membership

Corrupt:

```json
{
  "kind":"block",
  "blockType":"line4",
  "id":"l:danzer:0123",
  "points":[
    "p:danzer:012",
    "p:danzer:013",
    "p:danzer:023",
    "p:danzer:124"
  ],
  "orientation":"+"
}
```

Expected:

* `danzer.line-membership`

## 13.2 Degree mismatch

Delete one line.

Expected:

* 4 points drop to degree 3
* emit `danzer.point-degree`
* optionally also `danzer.count-mismatch`

## 13.3 Duplicate point

Emit both `p:danzer:012` twice.

Expected:

* `danzer.duplicate-point`

## 13.4 Duplicate line

Emit `l:danzer:0123` twice.

Expected:

* `danzer.duplicate-line`

---

## 14) Why Danzer is strong for your system

This kernel gives you all of this at once:

* built from **7** as the primitive ground set
* naturally about **triples** and **quads**
* self-dual
* exact finite generator
* clean Levi graph
* ideal for systolic scoring
* easy to project to the 240 shell
* no ambiguity about realizability or charts

It is much cleaner than 19₄ as a primary combinatorial kernel.

---

## 15) Recommended stack placement

Use Danzer as:

### Private/combinatorial kernel

```text
Fano → Danzer
```

### Shared closure kernel

```text
Pappus / Hesse / Miquel
```

### Global shell / canonicalization

```text
240 / E8 / Weyl
```

So:

```text
7-bit ground set
→ Danzer triples/quads kernel
→ closure theories
→ systolic/spectral scoring
→ 240-shell projection
```

That closes very cleanly.

---

Absolutely. Below is a **complete Danzer (35₄) v0 NDJSON fixture set**: **35 point records + 35 line records**, fully deterministic, with a **canonical digest recipe** you can pin in CI.

---

## Canonical digest recipe (pin this)

**Normalization rules**

1. Each record is JSON with:

   * keys ordered lexicographically (or use your existing canonical JSON normalizer)
   * no extra whitespace
2. Records are emitted in this order:

   * all `point` records, sorted by `id`
   * then all `block` records, sorted by `id`
3. Inside each `block`, the `points` array is sorted lexicographically.
4. The canonical artifact text is the **NDJSON** join of those records with `\n` line endings, and a trailing `\n` at end of file.

**Digest**

* `digest = sha256( UTF8(canonical_ndjson_text) )`

This lets you do a single golden hash check.

---

## Full fixture: `danzer35_4.v0.ndjson`

```json
{"kind":"point","id":"p:danzer:012","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:013","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:014","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:015","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:016","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:023","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:024","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:025","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:026","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:034","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:035","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:036","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:045","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:046","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:056","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:123","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:124","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:125","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:126","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:134","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:135","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:136","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:145","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:146","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:156","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:234","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:235","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:236","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:245","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:246","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:256","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:345","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:346","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:356","tags":["danzer35_4"]}
{"kind":"point","id":"p:danzer:456","tags":["danzer35_4"]}
{"kind":"block","blockType":"line4","id":"l:danzer:0123","orientation":"+","points":["p:danzer:012","p:danzer:013","p:danzer:023","p:danzer:123"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0124","orientation":"+","points":["p:danzer:012","p:danzer:014","p:danzer:024","p:danzer:124"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0125","orientation":"+","points":["p:danzer:012","p:danzer:015","p:danzer:025","p:danzer:125"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0126","orientation":"+","points":["p:danzer:012","p:danzer:016","p:danzer:026","p:danzer:126"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0134","orientation":"+","points":["p:danzer:013","p:danzer:014","p:danzer:034","p:danzer:134"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0135","orientation":"+","points":["p:danzer:013","p:danzer:015","p:danzer:035","p:danzer:135"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0136","orientation":"+","points":["p:danzer:013","p:danzer:016","p:danzer:036","p:danzer:136"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0145","orientation":"+","points":["p:danzer:014","p:danzer:015","p:danzer:045","p:danzer:145"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0146","orientation":"+","points":["p:danzer:014","p:danzer:016","p:danzer:046","p:danzer:146"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0156","orientation":"+","points":["p:danzer:015","p:danzer:016","p:danzer:056","p:danzer:156"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0234","orientation":"+","points":["p:danzer:023","p:danzer:024","p:danzer:034","p:danzer:234"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0235","orientation":"+","points":["p:danzer:023","p:danzer:025","p:danzer:035","p:danzer:235"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0236","orientation":"+","points":["p:danzer:023","p:danzer:026","p:danzer:036","p:danzer:236"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0245","orientation":"+","points":["p:danzer:024","p:danzer:025","p:danzer:045","p:danzer:245"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0246","orientation":"+","points":["p:danzer:024","p:danzer:026","p:danzer:046","p:danzer:246"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0256","orientation":"+","points":["p:danzer:025","p:danzer:026","p:danzer:056","p:danzer:256"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0345","orientation":"+","points":["p:danzer:034","p:danzer:035","p:danzer:045","p:danzer:345"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0346","orientation":"+","points":["p:danzer:034","p:danzer:036","p:danzer:046","p:danzer:346"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0356","orientation":"+","points":["p:danzer:035","p:danzer:036","p:danzer:056","p:danzer:356"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:0456","orientation":"+","points":["p:danzer:045","p:danzer:046","p:danzer:056","p:danzer:456"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1234","orientation":"+","points":["p:danzer:123","p:danzer:124","p:danzer:134","p:danzer:234"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1235","orientation":"+","points":["p:danzer:123","p:danzer:125","p:danzer:135","p:danzer:235"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1236","orientation":"+","points":["p:danzer:123","p:danzer:126","p:danzer:136","p:danzer:236"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1245","orientation":"+","points":["p:danzer:124","p:danzer:125","p:danzer:145","p:danzer:245"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1246","orientation":"+","points":["p:danzer:124","p:danzer:126","p:danzer:146","p:danzer:246"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1256","orientation":"+","points":["p:danzer:125","p:danzer:126","p:danzer:156","p:danzer:256"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1345","orientation":"+","points":["p:danzer:134","p:danzer:135","p:danzer:145","p:danzer:345"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1346","orientation":"+","points":["p:danzer:134","p:danzer:136","p:danzer:146","p:danzer:346"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1356","orientation":"+","points":["p:danzer:135","p:danzer:136","p:danzer:156","p:danzer:356"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:1456","orientation":"+","points":["p:danzer:145","p:danzer:146","p:danzer:156","p:danzer:456"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:2345","orientation":"+","points":["p:danzer:234","p:danzer:235","p:danzer:245","p:danzer:345"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:2346","orientation":"+","points":["p:danzer:234","p:danzer:236","p:danzer:246","p:danzer:346"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:2356","orientation":"+","points":["p:danzer:235","p:danzer:236","p:danzer:256","p:danzer:356"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:2456","orientation":"+","points":["p:danzer:245","p:danzer:246","p:danzer:256","p:danzer:456"],"ruleId":"danzer.generator","derivedFrom":[]}
{"kind":"block","blockType":"line4","id":"l:danzer:3456","orientation":"+","points":["p:danzer:345","p:danzer:346","p:danzer:356","p:danzer:456"],"ruleId":"danzer.generator","derivedFrom":[]}
```

---

## Optional: quick sanity counts you can assert in CI

* `count(kind=="point") == 35`
* `count(kind=="block" && blockType=="line4") == 35`
* for each point: degree in line4 blocks = 4
* for each line: `len(points)=4` and points are distinct

---

Here you go — **Wave30 Danzer lens v0**, consistent with the **exact lex point order** in the fixture and the **injective ring map**:

[
\mu(i) = (7i)\bmod 240,\quad i=0..34
]

---

## Lens artifact: `wave30.lens_danzer35_4.v0.json`

```json
{
  "type": "wave30.lens_danzer35_4",
  "v": 1,
  "lens_id": "lens:danzer35_4:v0:mu7mod240",
  "mu": { "kind": "linear", "a": 7, "mod": 240 },
  "point_order": [
    "p:danzer:012","p:danzer:013","p:danzer:014","p:danzer:015","p:danzer:016",
    "p:danzer:023","p:danzer:024","p:danzer:025","p:danzer:026",
    "p:danzer:034","p:danzer:035","p:danzer:036",
    "p:danzer:045","p:danzer:046",
    "p:danzer:056",
    "p:danzer:123","p:danzer:124","p:danzer:125","p:danzer:126",
    "p:danzer:134","p:danzer:135","p:danzer:136",
    "p:danzer:145","p:danzer:146",
    "p:danzer:156",
    "p:danzer:234","p:danzer:235","p:danzer:236",
    "p:danzer:245","p:danzer:246",
    "p:danzer:256",
    "p:danzer:345","p:danzer:346",
    "p:danzer:356",
    "p:danzer:456"
  ],
  "ring_map": {
    "p:danzer:012": 0,
    "p:danzer:013": 7,
    "p:danzer:014": 14,
    "p:danzer:015": 21,
    "p:danzer:016": 28,
    "p:danzer:023": 35,
    "p:danzer:024": 42,
    "p:danzer:025": 49,
    "p:danzer:026": 56,
    "p:danzer:034": 63,
    "p:danzer:035": 70,
    "p:danzer:036": 77,
    "p:danzer:045": 84,
    "p:danzer:046": 91,
    "p:danzer:056": 98,
    "p:danzer:123": 105,
    "p:danzer:124": 112,
    "p:danzer:125": 119,
    "p:danzer:126": 126,
    "p:danzer:134": 133,
    "p:danzer:135": 140,
    "p:danzer:136": 147,
    "p:danzer:145": 154,
    "p:danzer:146": 161,
    "p:danzer:156": 168,
    "p:danzer:234": 175,
    "p:danzer:235": 182,
    "p:danzer:236": 189,
    "p:danzer:245": 196,
    "p:danzer:246": 203,
    "p:danzer:256": 210,
    "p:danzer:345": 217,
    "p:danzer:346": 224,
    "p:danzer:356": 231,
    "p:danzer:456": 238
  },
  "render_suggestions": {
    "line_highlight_mode": "all6chords",
    "alt_pairing": "sorted_1-4_2-3",
    "point_style": "dot",
    "line_style": "chord"
  }
}
```

---

## One-liner for renderers

* To light all Danzer points: light LEDs in `values(ring_map)`.
* To highlight a line `l:danzer:abcd`:

  * its incident points are the 4 triples `{abc, abd, acd, bcd}`
  * map each triple through `ring_map`
  * then either draw **all 6** chords among them, or use the deterministic pairing rule.
