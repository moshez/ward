# Ward

Linear memory safety library for ATS2. Provides Rust-like guarantees (no buffer overflow, no use-after-free, no double-free, no mutable aliasing) through dependent and linear types, compiled to freestanding WASM.

## Build

**Prerequisites:** ATS2 toolchain must be installed first (see ATS2 Toolchain section below).

**IMPORTANT:** You MUST run `make check` locally and verify the build succeeds before committing any changes to `.sats` or `.dats` files.

```bash
make              # Build WASM + native exerciser
make check        # Build everything + run anti-exerciser
make wasm         # WASM only (build/ward.wasm)
make exerciser    # Native exerciser (builds and runs)
make anti-exerciser  # Verify unsafe code is rejected
make clean        # Remove build/
```

## Architecture

Six-layer memory safety system (see DESIGN.md):

```
Layer 6: tptr_borrow    — typed read-only shared access
Layer 5: tptr           — typed, bounds-checked, linear arrays
Layer 4: raw_borrow     — read views with counted freeze/thaw
Layer 3: safe_memcpy/set — size-proven memory operations
Layer 2: raw_advance    — pointer arithmetic with size tracking
Layer 1: raw_own        — sized linear memory ownership
Layer 0: malloc/free    — the unsafe world (never exposed)
```

All proofs are erased at runtime — zero overhead.

## Files

- `memory.sats` — type declarations (the specification)
- `memory.dats` — implementations (the "unsafe core" behind the safe interface)
- `exerciser.dats` — native exerciser that tests all 6 layers
- `wasm_exerciser.dats` — WASM exerciser exporting `ward_test_raw`, `ward_test_borrow`, `ward_test_typed`
- `anti/` — anti-exerciser: code that MUST fail to compile (use-after-free, double-free, buffer overflow, leak, write-while-frozen, out-of-bounds, thaw-with-borrows)
- `runtime.h` — freestanding WASM runtime: ATS2 macro infrastructure + ward type definitions
- `runtime.c` — bump allocator + memset/memcpy for WASM
- `ward_prelude.h` — native build: ward type macros for gcc
- `wasm_stubs/` — empty stubs for libats CATS files (not needed in freestanding mode)

## Key ATS2 Patterns

### Linear types as ownership

All ward types (`raw_own`, `tptr`, etc.) are `absvtype` — linear types that must be consumed exactly once. At runtime they are all erased to `ptr`. The type system enforces:

- `sized_free` **consumes** `raw_own` — can't use after free
- `raw_advance` **consumes** one `raw_own`, **produces** two — no double-free
- `raw_freeze` **consumes** `raw_own`, **produces** `raw_frozen` + `raw_borrow` — no write during shared read
- `raw_thaw` requires `raw_frozen(l, n, 0)` — can't thaw with outstanding borrows

### Dependent types as bounds

Array indices carry static constraints: `{i:nat | i < n}` means the index is proven in-bounds at compile time. Buffer sizes are tracked: `raw_own(l, n)` knows it owns `n` bytes. `safe_memset` requires `{n <= cap}`.

### Template functions

Typed operations (`tptr_get<int>`, `tptr_set<int>`, etc.) are ATS2 templates. Any file using them must include:

```ats
staload _ = "./memory.dats"  (* template resolution *)
```

### Avoiding ATS2 constraint solver limits

The solver can't reduce `sizeof(a)` at compile time. Use extern declarations to bridge:

```ats
extern fun _ward_malloc {n:pos} (n: int n): [l:agz] ptr l = "mac#malloc"
extern fun _ward_ptr_add {l:addr}{m:nat} (p: ptr l, m: int m): ptr(l+m) = "mac#ward_ptr_add"
```

### Reserved words

`prefix`, `op` are reserved keywords in ATS2. Do not use them as identifiers.

## Freestanding WASM Build

The WASM build uses three `-D` flags to suppress ATS2 runtime headers that require libc:

- `-D_ATS_CCOMP_HEADER_NONE_` — suppresses `pats_ccomp_*.h` (which need `setjmp.h`)
- `-D_ATS_CCOMP_EXCEPTION_NONE_` — suppresses exception handling
- `-D_ATS_CCOMP_PRELUDE_NONE_` — suppresses prelude CATS files

`runtime.h` provides all needed macros (type definitions, instruction set, prelude arithmetic). Stub CATS files in `wasm_stubs/` shadow the libats includes that `share/atspre_staload.hats` generates.

## ATS2 Toolchain

### Installation (no root required)

```bash
# Download ATS2 (integer-only version, no GMP dependency)
curl -sL "https://raw.githubusercontent.com/ats-lang/ats-lang.github.io/master/FROZEN000/ATS-Postiats/ATS2-Postiats-int-0.4.2.tgz" -o /tmp/ats2.tgz

# Extract to ~/.ats2
mkdir -p ~/.ats2
tar -xzf /tmp/ats2.tgz -C ~/.ats2

# Build patsopt
cd ~/.ats2/ATS2-Postiats-int-0.4.2
make -j$(nproc) -C src/CBOOT patsopt
mkdir -p bin
cp src/CBOOT/patsopt bin/patsopt
```

The Makefile defaults to `PATSHOME=$(HOME)/.ats2/ATS2-Postiats-int-0.4.2`.

### WASM Toolchain

Requires clang with wasm32 target and wasm-ld:

```bash
# Ubuntu/Debian
sudo apt-get install -y clang lld
```
