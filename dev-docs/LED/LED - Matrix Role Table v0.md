# LED / Matrix Role Table v0

## 1. Purpose

This document defines the role of the physical light surfaces used by the system:

* **circular LED modules**
* **the 241-LED concentric board**
* **optional square LED matrices**

It separates:

* **algebraic role**
* **combinatorial role**
* **geometric role**
* **runtime / protocol role**

This is an **advisory architecture map**, not a protocol ABI.

---

## 2. Design Rule

The board uses **two different display spaces**:

### A. Circular / ring space

Used for:

* cyclic state
* orbital motion
* handshake boundaries
* propagation
* public shell projection

### B. Square / matrix space

Used for:

* quotient displays
* Hadamard-style balancing
* BQM / residual analysis
* orthogonal projective rectification

Short form:

```text
rings = cyclic / orbital / topological
grids = orthogonal / quotient / rectifying
```

---

## 3. The 7-Bit Circular Module

The small circular module is treated as a **nested structure**:

```text
7 = 1 + 6
```

### 3.1 Center LED (1-bit)

**Role:** Identity Witness

Algebraic meaning:

* monoid identity
* shared centroid
* nullary anchor

Runtime meaning:

* start/lock bit
* shared projective origin
* orientation reference

### 3.2 Outer 6 LEDs (6-bit)

**Role:** Closure Witness

Algebraic meaning:

* quasigroup-style closure layer
* reconciliation of left/right constraints

Runtime meaning:

* local closure
* symbolic handshake
* first closed interaction layer

### 3.3 Whole 7-light module

**Role:** Fano Incidence Judge

Geometric meaning:

* local incidence checker
* parity / syndrome controller

Runtime meaning:

* validates local lifted state before propagation
* resolves ambiguity before boundary export

---

## 4. Nested Low-Bit Algebra

The low-bit roles are not separate physical rings.
They are **logical partitions** of the 7-bit module.

| Logical Layer | Physical Placement | Meaning             |
| ------------- | ------------------ | ------------------- |
| **1-bit**     | center LED         | identity / centroid |
| **2-bit**     | subset of outer-6  | left-query witness  |
| **4-bit**     | subset of outer-6  | right-query witness |
| **6-bit**     | full outer-6       | closure witness     |
| **7-bit**     | full module        | Fano judge          |

### 4.1 2-bit

**Role:** Left Query Witness

Meaning:

* directional query
* initiator asymmetry
* left-division control witness

### 4.2 4-bit

**Role:** Right Query Witness

Meaning:

* directional response
* dual asymmetry
* right-division control witness

### 4.3 6-bit

**Role:** Closure Witness

Meaning:

* left/right reconciliation
* unique closure layer
* handshake completion witness

---

## 5. Main 241-LED Circular Board

The concentric board is the main **global runtime shell**.

Its counts are:

```text
1
8
12
16
24
32
40
48
60
```

Total:

```text
241 = 240 + 1
```

---

## 6. Ring Role Table

### Center LED — 1

**Algebraic role:** Identity witness
**Geometric role:** shared projective centroid
**Runtime role:** observer / lock / reference

Short form:

```text
1 = anchor
```

---

### Ring — 8

**Algebraic role:** Composition ring
**Mathematical inspiration:** eight-square / octonionic composition layer
**Geometric role:** local 8-tuple basis
**Runtime role:** local symbolic composition

Short form:

```text
8 = compose
```

---

### Ring — 12

**Algebraic role:** Orientation buffer
**Geometric role:** directional staging shell
**Runtime role:** local orientation / routing hints / bridge preparation

Short form:

```text
12 = orient
```

---

### Ring — 16

**Algebraic role:** Pfister rectification ring
**Mathematical inspiration:** sixteen-square / quadratic-form lift
**Geometric role:** quadrant memory / square-lift layer
**Runtime role:** BQM staging / norm rectification / 4×4 partition memory

Short form:

```text
16 = rectify
```

Important note:

```text
16 is not treated as the next composition algebra.
It is treated as a post-composition quadratic rectifier.
```

---

### Ring — 24

**Algebraic role:** Dual bridge ring
**Geometric role:** 24-cell bridge / self-dual converter
**Runtime role:** private/public coordinate translation

Short form:

```text
24 = bridge
```

---

### Ring — 32

**Algebraic role:** Pre-handshake staging
**Geometric role:** expanded local packet band
**Runtime role:** packet assembly / replicated boundary preparation

Short form:

```text
32 = stage
```

---

### Ring — 40

**Algebraic role:** Boundary closure ring
**Combinatorial role:** 20 + 20 peer boundary
**Geometric role:** Jordan handshake boundary
**Runtime role:** peer reconciliation / residual determinant initialization

Short form:

```text
40 = handshake
```

Important note:

```text
40 is not the main propagation ring.
40 is the topological interface ring.
```

---

### Ring — 48

**Algebraic role:** Propagation engine
**Geometric role:** 6 sectors × 8 lanes
**Runtime role:** phase engine / directional propagation / transport sweep

Short form:

```text
48 = propagate
```

---

### Ring — 60

**Algebraic role:** Harmonic projection ring
**Geometric role:** public harmonic band
**Runtime role:** human-visible projection / smoothed engine output

Short form:

```text
60 = project
```

---

### Global Shell — 240

**Algebraic role:** public state shell
**Geometric role:** dense outer boundary
**Runtime role:** shared global state surface / outer pointer domain

Short form:

```text
240 = shell
```

---

### Whole Board — 241

**Algebraic role:** shell + identity
**Geometric role:** projectively anchored shell
**Runtime role:** total public runtime surface

Short form:

```text
241 = shell + centroid
```

---

## 7. Optional Square Matrix Role Table

Square matrices are not the main shell.
They are **rectification and quotient planes**.

---

### 4×4 Matrix

**Size:** 16 LEDs

**Role:** Quotient plane

Uses:

* Hadamard-16-style balancing
* local residual display
* 4-quadrant BQM summary
* quotient display invariant `|Q| = 16`

Short form:

```text
4×4 = quotient plane
```

---

### 8×8 Matrix

**Size:** 64 LEDs

**Role:** Intermediate composition / diagnostics plane

Uses:

* local basis debug
* 8-tuple composition diagnostics
* expanded parity / trace inspection

Short form:

```text
8×8 = diagnostic plane
```

---

### 16×16 Matrix

**Size:** 256 LEDs

**Role:** Shared projective squared space

Uses:

* `Q × Q` display when `|Q| = 16`
* BQM coupling plane
* orthogonal residual map
* Hadamard-style rectification surface
* pairwise interaction / solver memory

Short form:

```text
16×16 = rectification / memory plane
```

Important note:

```text
The 16×16 plane is the best candidate for the shared projective squared space.
The 241 circular board remains the primary global shell.
```

---

## 8. Combined Architecture

The surfaces are used together like this:

```text
local symbolic state
→ 7-bit modules judge and close
→ inner rings compose / orient / rectify
→ 24-ring bridges
→ 40-ring handshakes
→ 48-ring propagates
→ 60-ring projects
→ 240-shell publishes
→ 16×16 matrix rectifies / remembers / analyzes
```

---

## 9. ψ / Quotient Interpretation

If:

* `Δ` = validated clause complex
* `G` = operator monoid acting on `Δ`
* `π: Δ → Q` = display quotient

then:

### Circular rings display

* orbit structure
* cyclic stepping
* phase propagation
* shell realization

### Square matrices display

* quotient state
* orthogonal decomposition
* residual / energy / coupling structure

Short form:

```text
rings show the orbit
grid shows the quotient
```

---

## 10. Recommended Physical Build

### Always use

* **241 circular board** as primary runtime shell
* **7-bit circular modules** as local judges

### Add one matrix based on need

Use **4×4** if you want:

* compact quotient plane
* simple control display
* minimal Hadamard-style summary

Use **16×16** if you want:

* full rectification plane
* BQM coupling display
* shared projective squared space
* pairwise memory / solver surface

---

## 11. Final Role Summary

| Surface                  | Role                         |
| ------------------------ | ---------------------------- |
| **1-bit center**         | identity / centroid          |
| **2-bit logical subset** | left-query witness           |
| **4-bit logical subset** | right-query witness          |
| **6-bit outer hexagon**  | closure witness              |
| **7-bit module**         | Fano judge                   |
| **8 ring**               | composition                  |
| **12 ring**              | orientation                  |
| **16 ring**              | Pfister rectification        |
| **24 ring**              | self-dual bridge             |
| **32 ring**              | staging                      |
| **40 ring**              | handshake boundary           |
| **48 ring**              | propagation engine           |
| **60 ring**              | public projection            |
| **240 shell**            | global state                 |
| **241 board**            | shell + centroid             |
| **4×4 matrix**           | quotient plane               |
| **16×16 matrix**         | rectification / memory plane |

---

## 12. Status

```text
Status: advisory architectural map
Version: v0
```

This table is intended to stabilize the physical interpretation of the display surfaces before further runtime wiring.

If you want, I can next turn this into either a **machine-readable JSON artifact** or a **more formal house-style spec doc**.
