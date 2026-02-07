# "Better Rust" in ATS2 — Design Notes

## What this prototype demonstrates

A layered memory safety system that provides Rust-like guarantees through
ATS2's dependent and linear types, with strictly more expressiveness than
Rust's borrow checker.

## Layer stack

```
Layer 6: tptr_borrow    — typed read-only shared access
Layer 5: tptr           — typed, bounds-checked, linear arrays
Layer 4: raw_borrow     — read views with counted freeze/thaw
Layer 3: safe_memcpy/set — size-proven memory operations
Layer 2: raw_advance    — pointer arithmetic with size tracking
Layer 1: raw_own        — sized linear memory ownership
Layer 0: malloc/free    — the unsafe world (never exposed)
```

## Key invariants enforced at compile time

| Invariant | Mechanism |
|---|---|
| No buffer overflow | Dependent size index on raw_own/tptr |
| No use-after-free | Linear types (must consume exactly once) |
| No double-free | Linear types |
| No mutable aliasing | Linear ownership; must freeze before sharing |
| No write-during-shared-read | Freeze/thaw protocol with borrow counting |
| Bounds-checked indexing | Dependent index constraint `i < n` |

## Where this beats Rust

1. **Arbitrary size relationships**: You can prove `memcpy(dst, src, n)` is
   safe when dst has `m` bytes and `n <= m`, even when `m` and `n` come from
   different computation paths. Rust's borrow checker can't reason about
   arithmetic relationships between sizes.

2. **Split/rejoin**: You can split a buffer into arbitrary pieces and rejoin
   them later, with the type system tracking the sizes. Rust requires unsafe
   for this.

3. **Custom borrow protocols**: The freeze/thaw/borrow-count mechanism is
   user-defined, not hardcoded. You could implement region-based borrowing,
   hazard pointers, RCU-like protocols, etc.

4. **Zero runtime cost**: All proofs are erased. The generated C code is
   identical to what you'd write by hand.

## Caveats in this prototype

- The borrow counting in the demo uses some `$UNSAFE` casts because fully
  wiring up the dependent borrow count tracking through the demo's control
  flow would obscure the design. The `.sats` signatures are the real
  specification — the implementation just needs to satisfy them.

- `addr@` usage in the demo is a simplification. A production version would
  pair the linear proof with its pointer more ergonomically, likely with a
  dataviewtype that bundles them.

- The `sizeof` computation in `tptr_init` assumes a specific representation.
  A real version would use ATS2's `sizeof` properly with alignment padding.

## The AI angle

The `.sats` file is the **specification**. An AI generating implementations
only needs to make the typechecker happy. The proof obligations are:
- Consume every linear value exactly once
- Satisfy every dependent constraint
- Thread views correctly through freeze/thaw

These are mechanically checkable. The AI doesn't need to "understand" memory
safety — it just needs to produce terms that typecheck.
