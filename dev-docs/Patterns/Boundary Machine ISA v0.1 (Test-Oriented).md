## Boundary Machine ISA v0.1 (Test-Oriented)

**Status:** Draft / future embedded ISA target  
**Note:** The repository currently implements CLBC (CanvasL ByteCode) as the deterministic bytecode/VM target. Treat this ISA as a future embedded target unless/until a second VM backend is implemented.

### 1) Machine Model

**Word size:** `W = 32-bit` unsigned (wrapping arithmetic).

**Registers:**
- `R0..R7` (8 general registers)
- `PC` (program counter, instruction index)
- `SR` (status register bitfield)

**SR bits (minimum):**
- `Z` (zero) — last compare/eval result == 0
- `V` (valid) — last CHECK passed
- `E` (error) — sticky error (halts or traps depending on mode)

**Memory:**
- `MEM[0..N-1]` words (N fixed at load time)
- Memory is *always initialized* (no uninitialized reads allowed)

**Harvard-ish:** program is an array of instructions; data is MEM.

---

### 2) Determinism and Test Trace

The machine **MUST** support a trace stream. Each instruction **MUST** (if tracing enabled) emit a single compact trace record:

`(step, pc, opcode, a, b, c, r0hash, sr)`

- `step` increments each instruction.
- `r0hash` is a rolling hash of selected state (see HASH instruction below).
- This makes “same program” comparable across emulator + ESP32.

---

### 3) Instruction Encoding (Simple)

Use a fixed 32-bit instruction:

```
[ opcode:8 | a:8 | b:8 | c:8 ]
```

Interpretation depends on opcode:
- `a,b,c` are usually register indices or small immediates.
- Large immediates come from `MEM[PC+1]` via LDI (below) or from a CONST pool.

This keeps decoding tiny on ESP32.

---

## 4) Instruction Set

### A) Core Data + Control

**NOP**
- `NOP`
- Does nothing.

**HALT**
- `HALT code`
- Stops execution. `code` is `a` (0..255).  
- Emulator returns `(halt_code, final_state, final_trace_hash)`.

**MOV**
- `MOV ra, rb`
- `R[ra] = R[rb]`

**LD**
- `LD ra, [rb + imm8]`
- `R[ra] = MEM[ R[rb] + c ]` (c is unsigned byte)
- If out-of-bounds: set `SR.E=1` and either HALT(255) or TRAP (implementation choice, but MUST be deterministic).

**ST**
- `ST [rb + imm8], ra`
- `MEM[ R[rb] + c ] = R[ra]` with same bounds rule.

**LDI** (load immediate from const pool in memory)
- `LDI ra, imm_index`
- `R[ra] = MEM[ c ]` (use `c` as index into CONST region)
- Rule: CONST region is defined by loader; simplest is “low addresses are const”.

**JMP**
- `JMP rel8`
- `PC += sign_extend(a)` (or use `a` as signed)
- Define sign convention clearly and stick to it.

**JZ**
- `JZ rel8`
- If `SR.Z==1`, then branch like JMP.

**JVALID**
- `JVALID rel8`
- If `SR.V==1`, branch like JMP.

---

### B) Arithmetic (All wrapping mod 2^32)

**ADD**
- `ADD ra, rb, rc`
- `R[ra] = R[rb] + R[rc]`

**XOR**
- `XOR ra, rb, rc`
- `R[ra] = R[rb] XOR R[rc]`

**AND**
- `AND ra, rb, rc`

**SHL**
- `SHL ra, rb, imm5`
- `R[ra] = R[rb] << (c & 31)`

**CMPZ**
- `CMPZ rb`
- `SR.Z = (R[rb] == 0)`

(We keep arithmetic tiny; you can add MUL later if needed.)

---

### C) “CanvasL / Geometry” Semantic Primitives (Test-first)

These are the special ones: they encode your invariants directly and deterministically.

#### 1) POLY_EVAL (bounded polynomial evaluation)
**POLY**
- `POLY ra, rb, rc`
- Treat `MEM` as a “polynomial arena”.
- `rb` points to a polynomial descriptor in memory.
- `rc` points to variable vector in memory.
- Evaluates into `R[ra]`.

**Polynomial descriptor format in MEM** (simple & testable):
```
MEM[p+0] = degree d        (0..16)
MEM[p+1] = nvars n         (1..8)
MEM[p+2] = coeff_base addr
MEM[p+3] = term_count t    (0..255)  ; optional sparse form
...
```

Start with dense form if you want:
`value = Σ_{i=0..d} coeff[i] * x^i` (1 variable).
Then generalize later.

**Determinism rule:** all reads bounded; on failure set `SR.E=1`, `SR.V=0`.

#### 2) FANO_CHECK (incidence / line membership)
**FANO**
- `FANO ra, rb, rc`
- Interprets `R[rb], R[rc], R[ra]` as *point IDs* 1..7 (or 0..6).
- Sets `SR.V = 1` iff `{a,b,c}` is a valid Fano line.
- Sets `SR.Z = SR.V` (optional convenience).

**Canonical Fano lines (hardcoded):**
- {1,2,4} {2,3,5} {3,4,6} {4,5,7} {5,6,1} {6,7,2} {7,1,3}

This is extremely fast and perfect for automatic testing: you can use it as a gate.

#### 3) AREA_CHECK (optional, but matches your 8-tier validation style)
**AREA**
- `AREA ra, rb, rc`
- Reads BQF coefficients from memory and compares “area” under your chosen deterministic function.
- Sets `SR.V` for pass/fail.

You can postpone AREA until POLY + FANO + HASH are working.

---

### D) Hash / Trace Consistency (Automatic Testing Backbone)

**HASH**
- `HASH rb, mode`
- Updates a rolling hash register (choose `R7` as HASH accumulator by convention).
- `mode` selects what is hashed:
  - mode 0: hash `R0..R7 + SR`
  - mode 1: hash `R0..R3 + SR`
  - mode 2: hash `MEM[addr..addr+k]` (needs a descriptor)

**Recommended simple hash:** FNV-1a 32-bit or a tiny xorshift mix.
Deterministic, cheap, and same everywhere.

This is how you do automatic testing:
- expected hash from emulator
- compare hash from device run
- if mismatch, dump trace window

---

## 5) Execution Limits (For Testing)

To prevent runaway programs in fuzz/auto-tests:

**The VM MUST support:**
- `MAX_STEPS` hard limit (e.g., 1e6 emulator, 1e5 device)
- On limit reached: HALT(254) with `SR.E=1`

---

## 6) Loader / Program Format (Minimal)

A program bundle is:

1. `const region` in MEM (immutable by convention)
2. `data region` in MEM (mutable)
3. `instr[]` array

Optionally define:
- `MEM[0] = magic`
- `MEM[1] = const_end`
- `MEM[2] = data_end`
- `MEM[3] = entry_pc`

Keep it dead simple.

---

# CanvasL → ISA Mapping (Test-Oriented)

Here’s a **starter mapping table** that fits what you asked earlier (visual semantics + CanvasL mapping), but focused on compiling to tests:

| CanvasL Construct | Meaning | ISA Pattern |
|---|---|---|
| Node (feature) | state atom | `LDI/LD → Rk` then `HASH` |
| Edge | transition | compute + `FANO` / `POLY` |
| “Optional” / projective | may vanish / infinity | represent as point-id 0 or special const; gate with `JVALID` |
| Validation tier | accept/reject | `FANO/AREA → SR.V` then `JVALID` |
| Commit | advance clock | `HASH mode0` + `ST` vector-clock cell |

And for your 8-tuple ladder idea:

| 8-Tuple Slot | Geometric “dimension cue” | VM representation |
|---|---|---|
| 1: Q | point | `R0` as “current state id” |
| 2: Σ | line | input symbol stream in MEM; pointer in `R1` |
| 3: L | face | left boundary / base addr in `R2` |
| 4: R | tetra | right boundary / end addr in `R3` |
| 5: δ | 5-cell/sphere cue | transition kernel = `POLY` descriptor |
| 6: s | octa cue | start config = CONST block |
| 7: t | cube cue | accept predicate = `FANO/AREA + JVALID` |
| 8: r | higher polytope cue | reject predicate = `SR.E` or `HALT(code)` |

(We can refine the geometry cues later; the important thing is each slot maps to concrete machine state for testing.)

---

## 7) What This Gives You For Automatic Testing

You can now do:

1. Generate random CanvasL graphs → compile to ISA
2. Run in emulator → get `(halt_code, final_hash, trace_hash)`
3. Flash same program to ESP32 → run → get `(halt_code, final_hash)`
4. **Compare hashes**  
5. If mismatch, request last N trace records for bisect

That’s a real “physics-like” validation loop: invariant checks + trace consistency.