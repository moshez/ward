# Ward

Linear memory safety for ATS2. Ward provides Rust-like guarantees -- no buffer overflow, no use-after-free, no double-free, no mutable aliasing -- through dependent and linear types, compiled to freestanding WASM. All proofs are erased at runtime: zero overhead.

## Quick start

### Prerequisites

```bash
# ATS2 toolchain (no root required)
curl -sL "https://raw.githubusercontent.com/ats-lang/ats-lang.github.io/master/FROZEN000/ATS-Postiats/ATS2-Postiats-int-0.4.2.tgz" -o /tmp/ats2.tgz
mkdir -p ~/.ats2
tar -xzf /tmp/ats2.tgz -C ~/.ats2
cd ~/.ats2/ATS2-Postiats-int-0.4.2
make -j$(nproc) -C src/CBOOT patsopt
mkdir -p bin && cp src/CBOOT/patsopt bin/patsopt

# WASM toolchain (Ubuntu/Debian)
sudo apt-get install -y clang lld
```

## Using ward in your project

Every file that uses ward must include `staload _ = "...memory.dats"` for template resolution. For DOM operations, also staload `dom.sats`/`dom.dats`. For promises, `promise.sats`/`promise.dats`.

### Arrays

```ats
#include "share/atspre_staload.hats"
staload "path/to/lib/memory.sats"
staload _ = "path/to/lib/memory.dats"

fun example (): void = let
  val arr = ward_arr_alloc<int>(10)
  val () = ward_arr_set<int>(arr, 5, 42)
  val v = ward_arr_get<int>(arr, 5)       (* v = 42 *)
  val () = ward_arr_free<int>(arr)
in end
```

### Freeze / thaw borrow protocol

Freeze an array to get read-only borrows. The array cannot be mutated or freed until all borrows are dropped and it is thawed.

```ats
val arr = ward_arr_alloc<int>(10)
val () = ward_arr_set<int>(arr, 0, 42)
val @(frozen, borrow) = ward_arr_freeze<int>(arr)
val v = ward_arr_read<int>(borrow, 0)          (* read through borrow *)
val () = ward_arr_drop<int>(frozen, borrow)    (* drop borrow *)
val arr = ward_arr_thaw<int>(frozen)           (* thaw requires 0 borrows *)
val () = ward_arr_free<int>(arr)
```

### DOM operations

DOM operations thread a linear `ward_dom_state` through each call. Tag and attribute names must be `ward_safe_text` -- the compiler rejects any character outside `[a-zA-Z0-9-]`, preventing injection at compile time. Content values use `ward_arr_borrow` (read-only shared access). The `style` attribute has a dedicated setter.

```ats
staload "path/to/lib/dom.sats"
staload _ = "path/to/lib/dom.dats"

fun dom_example (): void = let
  val dom = ward_dom_init()

  (* Tag names are safe text -- compiler rejects unsafe characters *)
  val b = ward_text_build(3)
  val b = ward_text_putc(b, 0, char2int1('d'))
  val b = ward_text_putc(b, 1, char2int1('i'))
  val b = ward_text_putc(b, 2, char2int1('v'))
  val tag = ward_text_done(b)

  val dom = ward_dom_create_element(dom, 1, 0, tag, 3)

  (* Attribute names are safe text; values come from borrows *)
  val b = ward_text_build(2)
  val b = ward_text_putc(b, 0, char2int1('i'))
  val b = ward_text_putc(b, 1, char2int1('d'))
  val attr_name = ward_text_done(b)

  val vbuf = ward_arr_alloc<byte>(4)
  (* ... fill vbuf with content bytes ... *)
  val @(frozen, borrow) = ward_arr_freeze<byte>(vbuf)
  val dom = ward_dom_set_attr(dom, 1, attr_name, 2, borrow, 4)
  val () = ward_arr_drop<byte>(frozen, borrow)
  val vbuf = ward_arr_thaw<byte>(frozen)
  val () = ward_arr_free<byte>(vbuf)

  val dom = ward_dom_remove_children(dom, 1)
  val () = ward_dom_fini(dom)
in end
```

### Promises

Promises are linear and indexed by state (`Pending` or `Resolved`). The resolver is a separate linear value consumed by `resolve` -- you cannot resolve twice or forget to resolve. No error type parameter; use `Result(a, e)` as your `a` if you need errors.

```ats
staload "path/to/lib/promise.sats"
staload _ = "path/to/lib/promise.dats"

(* Pre-resolved promise: extract immediately *)
val p = ward_promise_resolved<int>(42)
val v = ward_promise_extract<int>(p)    (* v = 42 *)

(* Deferred resolution *)
val @(p, r) = ward_promise_create<int>()
val () = ward_promise_resolve<int>(r, 99)   (* consumes resolver *)
val () = ward_promise_discard<int><Pending>(p)

(* Chaining -- consumes the input promise *)
val @(p, r) = ward_promise_create<int>()
val p2 = ward_promise_then<int><int>(p, lam (x) => x + 1)
val () = ward_promise_resolve<int>(r, 10)   (* triggers callback, resolves p2 *)
val () = ward_promise_discard<int><Pending>(p2)
```

## API

### Memory types

| Type | Description |
|------|-------------|
| `ward_arr(a, l, n)` | Typed array: `n` elements of type `a` at address `l` |
| `ward_arr_frozen(a, l, n, k)` | Frozen array, `k` outstanding borrows |
| `ward_arr_borrow(a, l, n)` | Read-only borrow of typed array |
| `ward_safe_text(n)` | Read-only text, `n` bytes, compile-time character verified |
| `ward_text_builder(n, filled)` | Linear builder for safe text construction |

### Memory functions

| Function | What it does |
|----------|-------------|
| `ward_arr_alloc<a>(n)` | Allocate array of `n` elements |
| `ward_arr_free<a>(arr)` | Free array (consumes it) |
| `ward_arr_get<a>(arr, i)` | Read element `i` (bounds-checked) |
| `ward_arr_set<a>(arr, i, v)` | Write element `i` (bounds-checked) |
| `ward_arr_split<a>(arr, m)` | Split into two arrays at index `m` |
| `ward_arr_join<a>(left, right)` | Rejoin adjacent arrays |
| `ward_arr_freeze<a>(arr)` | Freeze: returns `(frozen, borrow)` |
| `ward_arr_thaw<a>(frozen)` | Thaw: requires 0 outstanding borrows |
| `ward_arr_dup<a>(frozen, borrow)` | Duplicate borrow (count +1) |
| `ward_arr_drop<a>(frozen, borrow)` | Drop borrow (count -1) |
| `ward_arr_read<a>(borrow, i)` | Read through borrow (bounds-checked) |
| `ward_arr_borrow_split<a>(frozen, borrow, m)` | Split borrow into sub-borrows |
| `ward_arr_borrow_join<a>(frozen, left, right)` | Rejoin sub-borrows |
| `ward_text_build(n)` | Start building safe text of length `n` |
| `ward_text_putc(b, i, c)` | Put character `c` at position `i` (must satisfy `SAFE_CHAR`) |
| `ward_text_done(b)` | Finish building (must have written all `n` positions) |
| `ward_safe_text_get(t, i)` | Read byte `i` from safe text |

### Promise types

| Type | Description |
|------|-------------|
| `ward_promise(a, s)` | Linear promise indexed by state (`Pending` or `Resolved`) |
| `ward_promise_resolver(a)` | Linear write-end, consumed by `resolve` |

No error type parameter. If you want errors, use `Result(a, e)` as your `a`.

### Promise functions

| Function | What it does |
|----------|-------------|
| `ward_promise_create<a>()` | Returns `(pending_promise, resolver)` pair |
| `ward_promise_resolved<a>(v)` | Create an already-resolved promise |
| `ward_promise_resolve<a>(r, v)` | Resolve (consumes the resolver) |
| `ward_promise_extract<a>(p)` | Extract value (requires `Resolved`) |
| `ward_promise_discard<a>(p)` | Explicitly discard any promise |
| `ward_promise_then<a><b>(p, f)` | Chain callback (consumes promise, returns new one) |

### DOM types

| Type | Description |
|------|-------------|
| `ward_dom_state(l)` | Linear DOM diff buffer at address `l` |

### DOM functions

All DOM operations consume and return `ward_dom_state` (linear threading). Tag and attribute names require `ward_safe_text`; content values require `!ward_arr_borrow` (borrowed, not consumed).

| Function | What it does |
|----------|-------------|
| `ward_dom_init()` | Allocate DOM diff buffer |
| `ward_dom_fini(state)` | Free DOM diff buffer (consumes it) |
| `ward_dom_create_element(state, node_id, parent_id, tag, tag_len)` | Create element (tag must be safe text) |
| `ward_dom_set_text(state, node_id, text, text_len)` | Set text content (from borrow) |
| `ward_dom_set_attr(state, node_id, attr_name, name_len, value, value_len)` | Set attribute (name must be safe text, value from borrow) |
| `ward_dom_set_style(state, node_id, value, value_len)` | Set style (dedicated setter -- value from borrow) |
| `ward_dom_remove_children(state, node_id)` | Remove all children of a node |

## How it works

**Linear types as ownership.** Ward types are `absvtype` -- linear types that must be consumed exactly once. At runtime they erase to `ptr`. The compiler enforces that every array is freed, every promise is handled, every resolver is used.

**Dependent types as bounds.** Array indices carry static constraints: `{i:nat | i < n}` means the index is proven in-bounds at compile time. Buffer sizes are tracked through split/join.

**Datasort as state.** `datasort PromiseState = Pending | Resolved` creates a compile-time-only tag. `extract` only accepts `Resolved`; `then` only accepts `Pending`. The sort is fully erased at runtime.
