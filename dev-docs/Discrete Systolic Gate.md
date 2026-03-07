Alright — here’s the **drop-in NDJSON + kernel contract** for a **Discrete Systolic Gate** that fits your existing runtime ladder (`canon → compile → close → score → project`) , your **small-circuit** failure style , and your **content-addressed / CID→Transform→CID** discipline .

I’m going to specify:

1. **Record types** (NDJSON)
2. **Canonicalization + hashing** rules (deterministic across runtimes)
3. **Complex construction** (Levi graph + 2-cells)
4. **Systole algorithm v0** (bounded, certificate-producing)
5. **CI invariants** and expected behaviors

---

# 0) Position in the engine

This is a **Score/Gate** module attached to `score(S*) -> metrics` .

* Input: a closed incidence state `S*` (points + blocks + orientation/provenance)  
* Output: metrics + **minimal circuits** (witness cycles) 

It does **not mutate** incidence; it emits *certificates* so policy can quarantine, similar in spirit to other gates.

---

# 1) NDJSON record types

We’ll add **three** record families:

* `complex.*` — deterministic derived combinatorial complex
* `systole.*` — score output + certificates
* `digest.*` — optional commitments for “projection-only artifacts”

These are **derived artifacts**: they should carry `source_ref` back to the `S*` CID / hash.

## 1.1 `complex.header` (one per build)

```json
{
  "type": "complex.header",
  "v": 1,
  "complex_id": "cx:sha256:…",
  "source_ref": "cid:…",                 
  "build": {
    "kind": "levi+faces-from-blocks",
    "params": {
      "attach_faces": true,
      "face_rule": "block-alt-cycle",
      "max_block_size": 64
    }
  },
  "basis_hash": "sha256:…",
  "created_at": 0
}
```

Notes:

* `basis_hash` is the relabeling/uniqueness anchor you already use .
* `source_ref` should be the CID of the closed state (or its manifest hash), consistent with your Merkle trace approach .

## 1.2 `complex.vertex`

A vertex is either a point or a block (line) node in the Levi graph.

```json
{
  "type": "complex.vertex",
  "v": 1,
  "complex_id": "cx:sha256:…",
  "vid": "V:pt:p123",           
  "kind": "point",
  "ref": "pt:p123"
}
```

```json
{
  "type": "complex.vertex",
  "v": 1,
  "complex_id": "cx:sha256:…",
  "vid": "V:blk:cid:block:…",
  "kind": "block",
  "ref": "cid:block:…",
  "ori": "+"                    
}
```

* `ori` mirrors your per-block orientation bit structure .

## 1.3 `complex.edge`

Each incidence becomes an undirected edge.

```json
{
  "type": "complex.edge",
  "v": 1,
  "complex_id": "cx:sha256:…",
  "eid": "E:sha256:…",
  "u": "V:pt:p123",
  "vtx": "V:blk:cid:block:…",
  "incidence": {
    "point": "pt:p123",
    "block": "cid:block:…"
  }
}
```

## 1.4 `complex.face`

This is the key: we attach 2-cells so we can define **contractible** loops.

### Face rule v0: “block alternating cycle”

If a block contains points `[p0,p1,…,p{k-1}]` (in canonical order), the face boundary is the cycle:

`(blk—p0—blk—p1—blk—…—p{k-1}—blk)` in the Levi graph.

Encode boundary as edge IDs in order:

```json
{
  "type": "complex.face",
  "v": 1,
  "complex_id": "cx:sha256:…",
  "fid": "F:sha256:…",
  "face_kind": "block-alt-cycle",
  "block_ref": "cid:block:…",
  "boundary": {
    "edges": ["E:…","E:…","E:…"],
    "closed": true
  }
}
```

This “fills” the obvious per-block cycles, making them **contractible** by definition.

> This matches your architecture: the closure engine outputs blocks with provenance , and scoring reasons about invariants thereafter .

---

# 2) Canonicalization & hashing rules (deterministic)

This must align with “all ops deterministic and content-addressed” .

## 2.1 Canonical JSON

To hash any record:

1. remove fields: `created_at`, `note`, any UI-only fields
2. sort object keys lexicographically
3. arrays are preserved in order **only if** the record type defines an order; otherwise sort.

## 2.2 Vertex IDs

* Point vertex id: `V:pt:<PointId>`
* Block vertex id: `V:blk:<BlockCid>`

## 2.3 Edge IDs

Edge is undirected; canonicalize endpoints so `u < vtx` lexicographically.

`eid = "E:sha256:" + H("edge" || u || vtx || complex_id)`

## 2.4 Face IDs

`fid = "F:sha256:" + H("face" || face_kind || block_ref || join(boundary.edges, ","))`

## 2.5 Complex ID

`complex_id = "cx:sha256:" + H(source_ref || basis_hash || build.kind || build.params.canon)`

This is consistent with your field projection practice: deterministic address from `(topic || prev || t || basis)`  and your general hashing discipline .

---

# 3) The Discrete Systolic Gate output records

## 3.1 `systole.score`

```json
{
  "type": "systole.score",
  "v": 1,
  "gate_id": "systole.discrete.v0",
  "source_ref": "cid:…",
  "complex_ref": "cx:sha256:…",
  "metrics": {
    "V": 0,
    "E": 0,
    "F": 0,
    "components": 1,

    "girth": 0,                
    "sys_pi1": 0,              
    "betti1_F2": 0,            
    "density": 0.0,

    "sys_ratio": 0.0           
  },
  "thresholds": {
    "min_sys_pi1": 10,
    "max_density": 4.0
  },
  "status": "ok",
  "flags": []
}
```

### Metric meanings

* `girth`: shortest simple cycle length in Levi graph
* `sys_pi1`: shortest **non-contractible** cycle length in the 2-complex
* `betti1_F2`: rank of (H_1(K;\mathbb F_2))
* `sys_ratio`: a curvature-free “quality” ratio. v0 definition:

[
\text{sys_ratio} := \frac{\text{sys_pi1}^2}{\max(1, |E|)}
]

(You can swap `|E|` for a spectral energy later to align with your Seidel/Lyapunov scoring  .)

## 3.2 `systole.circuit`

When the gate fails or flags, it emits a small witness (cycle) — matching your “small circuit property” requirement .

```json
{
  "type": "systole.circuit",
  "v": 1,
  "gate_id": "systole.discrete.v0",
  "source_ref": "cid:…",
  "complex_ref": "cx:sha256:…",
  "circuit_id": "C:sha256:…",
  "kind": "cycle",
  "cycle": {
    "vertices": ["V:pt:…","V:blk:…","V:pt:…"],
    "edges": ["E:…","E:…","E:…"],
    "length": 12
  },
  "witness": {
    "is_noncontractible": true,
    "reason": "cycle not in span(im ∂2) over F2",
    "proof": {
      "mode": "F2-linear",
      "max_cycle_len_checked": 16
    }
  }
}
```

---

# 4) Kernel interface contract (what Codex implements)

This is a pure deterministic transform in your “kernel execute” style .

## 4.1 Transform name

* `build-complex.levi-faces.v1`
* `gate-score.systole.discrete.v0`

## 4.2 Input / output

**Input**: `S*` as NDJSON (points, blocks, ori map) — consistent with your closure output  .

**Output**:

* `complex.header`
* all `complex.vertex`, `complex.edge`, `complex.face`
* `systole.score`
* zero or more `systole.circuit`

---

# 5) Algorithm v0 (bounded, certificate-producing)

You asked for “derive numerical invariant from closed reference symbols.” Here is the exact v0 algorithm that does that.

## 5.1 Build Levi graph

* `V = points ∪ blocks`
* `E = incidences`
* Keep it undirected, bipartite.

## 5.2 Attach faces (`∂2`)

For each block containing points `P = [p0..p{k-1}]`:

* canonicalize point order (lex / basis-normalized)
* boundary edges are the alternating incidence edges `(blk,p0),(blk,p1),…`
* attach `complex.face`

This makes those per-block loops contractible.

## 5.3 Compute `girth`

Standard BFS girth per vertex (or per component). Output smallest cycle length.

## 5.4 Compute `betti1_F2`

Let:

* (C_1 = \mathbb F_2^{E})
* (C_2 = \mathbb F_2^{F})

Build the boundary matrix:

* (∂_2: C_2 → C_1) where each face maps to the sum (mod 2) of its boundary edges.

Then:

* (Z_1 = \ker(∂_1)) but in a graph complex you can shortcut using:
* ( \dim Z_1 = |E| - |V| + c ) where `c = #components`
* (B_1 = \mathrm{im}(∂_2)) has dimension `rank(∂2)`
* so:

[
\beta_1 = (|E|-|V|+c) - \mathrm{rank}(∂_2)
]

## 5.5 Compute `sys_pi1` (shortest non-contractible cycle)

This is the “systole” analog:

1. Enumerate simple cycles up to length `L` (v0: L=16 or 20)

   * In bipartite Levi graphs, all cycles are even; that’s fine.
2. For each candidate cycle `γ`, build its edge-incidence vector `v_γ ∈ C_1` over (\mathbb F_2).
3. Test whether `v_γ ∈ im(∂2)` (solve linear system over (\mathbb F_2)).

   * If yes: it’s contractible (filled by faces), skip.
   * If no: it’s essential; record `sys_pi1 = len(γ)` and emit `systole.circuit` witness.

If none found up to L:

* set `sys_pi1 = ">L"` in metrics and treat as “good” / “unknown-high.”
  (v0 can encode as `sys_pi1: 999999` + `flags:["sys_pi1_lower_bound_only"]`.)

This yields a **numerical invariant** plus a **minimal certificate** when it’s small — exactly your reliability style .

---

# 6) CI invariants and “golden tests”

These are the tests you can enforce in CI alongside your other guards.

## 6.1 Determinism invariants

* same `source_ref` + same `basis_hash` ⇒ same `complex_id` (byte-for-byte output ordering normalized)
* `systole.score.metrics` reproducible across platforms (use exact F2 linear algebra)

This matches “deterministic replay / consensus on state”  and “all operations deterministic and content-addressed” .

## 6.2 Small circuit property

If `sys_pi1 < min_sys_pi1`, you must emit at least one `systole.circuit` with:

* `cycle.length == sys_pi1`
* `is_noncontractible == true`
* `cycle.edges` exist in `complex.edge`

This matches your “fails by producing small minimal conflicting subsets” requirement .

## 6.3 Stability alignment

Optionally include the Seidel spectral score later, but v0 already aligns with your stated “spectral stability later / circuit extraction now” plan  .

---

# 7) How it ties back to your “systolic geometry” intuition (without importing continuum)

Your Wikipedia instinct translates directly:

* manifold (M) ↦ closed incidence state (S^*)
* “volume” ↦ discrete size/energy (`|E|`, or later Seidel energy) 
* “shortest noncontractible loop” ↦ `sys_pi1` in the 2-complex
* “Hurwitz / (2,3,7) / quaternion order gives good systoles” ↦ your design target is configurations with **large sys_pi1 relative to size**, which is a clean decentralization hardness heuristic (attackers are forced into short, debuggable witnesses when cheating).

And crucially: this is *exactly* the kind of “numerical invariant from closed reference symbols” you said you think you’re doing.

---

If you want the next increment after v0: I’ll extend the face rules so the 2-cells correspond not only to “block alt cycles,” but also to your named closure regimes (Möbius–Kantor, Pappus, Hesse)  — so the systole becomes an invariant of *that specific closure theory*, not just of the raw blocks.
