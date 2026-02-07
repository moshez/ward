# Ward

Linear memory safety library for ATS2. Provides Rust-like guarantees (no buffer overflow, no use-after-free, no double-free, no mutable aliasing) through dependent and linear types, compiled to freestanding WASM.

## Design Principles

**Safety by construction, not by inspection.** If no new `praxi` statements or `$UNSAFE` operations are added, safety cannot degrade. For example, `ward_safe_text` verifies each character via the constraint solver at compile time — a programmer cannot accidentally fat-finger a quote character into an attribute name and have compilation pass. Safe values are constructed safely, not checked after the fact.

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

Unified typed array system — no untyped layer. Byte buffers use `ward_arr<byte>`.

```
ward_safe_text       — compile-time verified read-only text (non-linear)
ward_arr_borrow      — typed read-only shared access
ward_arr_frozen      — frozen typed array with borrow counting
ward_arr             — typed, bounds-checked, linear arrays
malloc/free          — the unsafe world (never exposed)
```

All functions prefixed `ward_` for easy auditing. No raw pointer extraction — safety guarantees are inescapable. All proofs are erased at runtime — zero overhead.

## API

### Types

| Type | Description |
|------|-------------|
| `ward_arr(a, l, n)` | Typed array of `n` elements of type `a` at address `l` |
| `ward_arr_frozen(a, l, n, k)` | Frozen typed array, `k` outstanding borrows |
| `ward_arr_borrow(a, l, n)` | Read-only borrow of typed array |
| `ward_safe_text(n)` | Non-linear read-only text, `n` bytes, compile-time character verified |
| `ward_text_builder(n, filled)` | Linear builder for safe text construction |

### Functions

| Function | Signature |
|----------|-----------|
| `ward_arr_alloc<a>(n)` | `{n:pos} → [l:agz] ward_arr(a, l, n)` |
| `ward_arr_free<a>(arr)` | `ward_arr(a, l, n) → void` |
| `ward_arr_get<a>(arr, i)` | Read element `i`, `{i < n}` |
| `ward_arr_set<a>(arr, i, v)` | Write element `i`, `{i < n}` |
| `ward_arr_split<a>(arr, m)` | Split into `@(ward_arr(l, m), ward_arr(l+m, n-m))` |
| `ward_arr_join<a>(left, right)` | Rejoin adjacent arrays |
| `ward_arr_freeze<a>(arr)` | `→ @(ward_arr_frozen(l, n, 1), ward_arr_borrow(l, n))` |
| `ward_arr_thaw<a>(frozen)` | `ward_arr_frozen(l, n, 0) → ward_arr(l, n)` |
| `ward_arr_dup<a>(frozen, borrow)` | Increment borrow count, return new borrow |
| `ward_arr_drop<a>(frozen, borrow)` | Decrement borrow count, consume borrow |
| `ward_arr_read<a>(borrow, i)` | Read element `i` through borrow |
| `ward_arr_borrow_split<a>(frozen, borrow, m)` | Split borrow into two sub-borrows (count +1) |
| `ward_arr_borrow_join<a>(frozen, left, right)` | Rejoin sub-borrows (count -1) |
| `ward_text_build(n)` | `{n:pos} → ward_text_builder(n, 0)` |
| `ward_text_putc(b, i, c)` | `{SAFE_CHAR(c)} → ward_text_builder(n, i+1)` |
| `ward_text_done(b)` | `ward_text_builder(n, n) → ward_safe_text(n)` |
| `ward_safe_text_get(t, i)` | Read byte `i` from safe text |

### SAFE_CHAR predicate

```ats
stadef SAFE_CHAR(c:int) =
  (c >= 97 && c <= 122)       (* a-z *)
  || (c >= 65 && c <= 90)     (* A-Z *)
  || (c >= 48 && c <= 57)     (* 0-9 *)
  || c == 45                  (* - *)
```

Characters are verified by passing `char2int1('c')` which preserves the static index for the constraint solver. The solver checks each character at compile time — no runtime cost, no possibility of unsafe characters.

## Files

- `memory.sats` — type declarations (the specification): 5 types, 17 functions
- `memory.dats` — implementations (the "unsafe core" behind the safe interface)
- `exerciser.dats` — native exerciser that tests all operations
- `wasm_exerciser.dats` — WASM exerciser exporting `ward_test_raw`, `ward_test_borrow`, `ward_test_typed`, `ward_test_safe_text`
- `anti/` — anti-exerciser: code that MUST fail to compile (use-after-free, double-free, buffer overflow, leak, write-while-frozen, out-of-bounds, thaw-with-borrows, unsafe-char)
- `runtime.h` — freestanding WASM runtime: ATS2 macro infrastructure + ward type definitions
- `runtime.c` — bump allocator + memset/memcpy for WASM
- `ward_prelude.h` — native build: ward type macros for gcc
- `wasm_stubs/` — empty stubs for libats CATS files (not needed in freestanding mode)

## Key ATS2 Patterns

### No raw pointer extraction

There is no way to recover a `ptr l` from any ward type. All memory operations take the proof directly — the pointer is hidden inside. This means safety guarantees cannot be circumvented.

### Linear types as ownership

Ward array types are `absvtype` — linear types that must be consumed exactly once. At runtime they are all erased to `ptr`. The type system enforces:

- `ward_arr_free` **consumes** `ward_arr` — can't use after free
- `ward_arr_split` **consumes** one `ward_arr`, **produces** two — no double-free
- `ward_arr_freeze` **consumes** `ward_arr`, **produces** `ward_arr_frozen` + `ward_arr_borrow` — no write during shared read
- `ward_arr_thaw` requires `ward_arr_frozen(a, l, n, 0)` — can't thaw with outstanding borrows
- `ward_text_builder` is linear — must be completed with `ward_text_done`
- `ward_safe_text` is non-linear (`abstype`) — permanent, no free needed

### Dependent types as bounds

Array indices carry static constraints: `{i:nat | i < n}` means the index is proven in-bounds at compile time. Buffer sizes are tracked through split/join.

### Template functions

All ward operations are ATS2 templates. Any file using them must include:

```ats
staload _ = "./memory.dats"  (* template resolution *)
```

### Avoiding ATS2 constraint solver limits

The solver can't reduce `sizeof(a)` at compile time. Inside the `local` block, use:

```ats
val tail = $UNSAFE.cast{ptr(l+m)}(ptr_add<a>(arr, m))
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
