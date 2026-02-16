# Platform Usage Guidelines

Guidelines for projects that use ward as a vendored dependency. These rules ensure that application code upholds the same safety guarantees that ward provides.

## Setup

Symlink this file into your project's Claude Code rules so it is always active:

```bash
mkdir -p .claude/rules
ln -s ../../vendor/ward/docs/platform-usage.md .claude/rules/platform-usage.md
```

Adjust the relative path if your vendor directory is located elsewhere.

## MOST IMPORTANT

**Be fanatic about safety** -- NOT BEING FANATIC IS NOT ACCOMPLISHING YOUR GOALS. TRUST NOTHING. Auditing or checking are NOT RELIABLE. Only ATS2-provable safety matters. It is unacceptable to work around safety, even if it's "small". If something is truly absolutely impossible to express safely in ATS2, file a bug against ward. Note that ward might well reject any bug that is not well justified.

## Build

**Prerequisites:** ATS2 toolchain must be installed first (see ward's CLAUDE.md for installation instructions).

**IMPORTANT:** You MUST build locally and verify success before committing any changes to `.sats` or `.dats` files. NEVER COUNT ON CI TO VERIFY ATS2 BUILD. If the ATS2 toolchain is not available, install it first before making any code changes.

## Rules

1. **Dependent types enforce correctness** -- if it compiles, the behavior is correct.
2. **Never work around ward bugs** -- if ward has a bug, STOP and give the user a bug report instead of working around it. Do not patch vendored ward files or add workarounds in application code. The user will report the issue upstream and have it fixed.
3. **Minimize C code** -- All application code should be in ATS2. Ward's `runtime.h` provides codegen macros and `atspre_*` arithmetic. If an algorithm can be expressed with ward_arr_set/get, div/mod, and existing extern funs, it belongs in ATS2. Any new C code requires justification: (a) external research showing this operation is conventionally done in C, (b) what ATS2-only solutions were tried and why they don't work, (c) trade-offs, and (d) why the C implementation is safe.
4. **Be fanatic about safety** -- Auditing or checking are NOT RELIABLE. Only ATS2-provable safety matters. It is unacceptable to work around safety, even if it's "small". If something is truly absolutely impossible to express safely in ATS2, file a bug against ward. Note that ward might well reject any bug that is not well justified.
5. **Fanaticism is retroactive** -- If a fix uncovers previous lack of commitment to fanaticism, fixing that overrides all current concerns and must be dealt with immediately. Existing code that lacks proofs, uses magic numbers, or has dead code is not "consistent with existing patterns" -- it is a deficiency that must be corrected when discovered.

## Type Safety Requirements

**All new functionality must be proven correct using ATS2's type system.** Avoid writing plain C in `%{` blocks when dataprops can enforce invariants at compile time.

The goal is **functional correctness**, not just safety. Prove that code *does the right thing*, not merely that it *doesn't crash*.

### Functional Correctness Examples

Use dataprops to encode relationships that guarantee correct behavior:

```ats
(* Lookup: prove the returned entry corresponds to the queried key *)
dataprop MAPS(key: int, value_idx: int) =
  | {k,i:nat} ENTRY_FOR(k, i)  (* key k maps to value index i *)

fun lookup {k:int}
  (key: int(k)): [i:int] (MAPS(k, i) | int(i))

(* Navigation: prove we land on the requested target *)
dataprop AT_TARGET(int) =
  | {t:nat} VIEWING(t)

fun go_to {target:nat}
  (t: int(target)): (AT_TARGET(target) | void)
```

### Safety as a Byproduct

Functional correctness proofs often imply safety, but safety alone is insufficient:

- Bounded array access proves you read *the correct element*, not just *some valid element*
- State machine proofs ensure operations happen *in the right order*, not just *without crashing*
- Linear resource tracking proves DOM nodes are *correctly parented*, not just *not leaked*

If C code is unavoidable, document why dataprops couldn't be used and what runtime checks substitute for compile-time proofs.

### UI and Application Logic Proofs

UI code (state machines, event routing, async callback dispatch) must also be proven correct:

- **App state machines**: Define `dataprop` or `absprop` for valid app states and transitions. Prove that state changes only follow valid paths.
- **Node ID mappings**: When DOM node IDs map to application-level indices, prove the mapping is correct using `dataprop`.
- **Async callback dispatch**: Prove that callback routing delivers to the correct handler based on pending operation state.
- **Serialization roundtrips**: When data is serialized for storage and later deserialized, prove the roundtrip preserves the data using `absprop`.

```ats
(* App state machine: prove only valid transitions *)
dataprop APP_STATE_VALID(state: int) =
  | APP_INIT(0) | APP_LOADING(1) | APP_READY(2)

(* Serialization roundtrip: prove restore undoes serialize *)
absprop SERIALIZE_ROUNDTRIP(serialize_len: int, restore_ok: int)
```

## Converting C Blocks to ATS2

C `%{` blocks bypass all ATS2 type checking. Convert them to pure ATS whenever possible. The general pattern:

### Step 1: Declare C primitives as extern

Move irreducible C operations (byte access, bitwise ops, pointer arithmetic) to a header as macros, then declare them in `.sats`:

```ats
(* .sats -- declare the primitive *)
fun buf_get_u8(p: ptr, off: int): int = "mac#"
fun buf_set_u8(p: ptr, off: int, v: int): void = "mac#"
```

```c
/* header -- implement the primitive */
#define buf_get_u8(p, off) (((unsigned char*)(p))[(off)])
#define buf_set_u8(p, off, v) (((unsigned char*)(p))[(off)] = (unsigned char)(v))
```

### Step 2: Move global state to C files

Don't keep `static` variables in `%{` blocks. Put them in C files with getter/setter functions declared as `= "mac#"` in `.sats`.

### Step 3: Write ATS implementations using the primitives

Use `fn` for non-recursive module-local helpers, `implement` for `.sats` functions. Both support `{...}` template parameters.

### Freestanding arithmetic

ATS2's built-in `+`, `*`, `>=`, `>` generate prelude template dispatch calls (`g0int_add`, `g0int_mul`, etc.) that don't exist in freestanding mode. Replace them with explicit extern functions and overloads:

```ats
extern fun add_int_int(a: int, b: int): int = "mac#myapp_add"
extern fun mul_int_int(a: int, b: int): int = "mac#myapp_mul"
overload + with add_int_int of 10   (* priority 10 beats built-in *)
overload * with mul_int_int of 10
```

For comparisons, explicit function calls are more reliable than overloads (overloads for `>=` can remain ambiguous):

```ats
extern fun gte_int_int(a: int, b: int): bool = "mac#myapp_gte"
(* Use: if gte_int_int(x, 255) then ... *)
```

### g0int vs g1int

Plain `int` is `g0int` (untracked). `int c` from `[c:nat] int c` is `g1int` (dependent, statically indexed). These are **different types** -- g0int overloads don't match g1int arguments, causing ATS2 to fall back to prelude templates (`g1int_mul`, `g1int_add`). Solutions:

- Use plain `int` returns when you don't need the static index
- Add separate g1int overloads if you need dependent arithmetic
- Use `castfn` to explicitly cast between the two

### ATS2 keywords to avoid

`op` is a reserved keyword in ATS2. Don't use it as any identifier -- not in dynamic variables, static variables, or dataprop indices. Use `opc`, `opcode`, etc.

### Runtime macros

Freestanding ATS2 code may need these macros in a runtime header:

- `ATSPMVi0nt(i)` -- plain integer literals
- `ATSPMVintrep(i)` -- statically-indexed integer representations
- `ATSPMVcastfn(castfn, ty, val)` -- zero-cost type casts
- `ATSextfcall(f, args)` -- external function calls via `$extfcall`

### dataprop parameters are erased

Adding a `dataprop` proof parameter to a `= "mac#"` function does NOT change its C signature. C callers continue to work unchanged. This means you can strengthen ATS interfaces with proof requirements without breaking C code.

## Writing Dataprops

Dataprops are compile-time proofs that are completely erased at runtime. Use them to make invalid states unrepresentable.

### Whitelist pattern: enumerate valid values

When only specific values are legal, create a dataprop with one constructor per valid value. The constructors ARE the whitelist -- no other values can produce a proof:

```ats
dataprop VALID_OPCODE(opc: int) =
  | OPCODE_SET_TEXT(1)
  | OPCODE_SET_ATTR(2)
  | OPCODE_CREATE_ELEMENT(4)

(* Only way to call: emit_diff(OPCODE_SET_TEXT(), 1, ...) *)
fn emit_diff {opc:int}
  (pf: VALID_OPCODE(opc), opcode: int opc, ...): void
```

This is stronger than `#define` constants -- even if you use the right numeric value, you must also produce the matching proof.

### Sized buffer pattern: capacity as a type property

Don't hardcode buffer sizes in consumer modules. Instead, define a general-purpose pointer type that carries remaining capacity as a phantom type index. The concrete size appears ONLY at the buffer's definition site; downstream modules reference the capacity through the type, never through a literal.

```ats
(* Buffer pointer that knows its remaining capacity -- erased to ptr *)
abstype sized_buf(cap: int) = ptr

(* Concrete size appears ONLY here, at the definition site *)
stadef BUF_CAP = 4096

(* Accessor returns a sized_buf -- callers get capacity from the type *)
fun get_buf(): sized_buf(BUF_CAP) = "mac#get_buffer_ptr"

(* Writing checks len <= remaining capacity *)
fun sbuf_write {cap,l:nat | l <= cap}
  (dst: sized_buf(cap), src: ptr, len: int l): void = "mac#sbuf_write"

(* Advancing reduces remaining capacity *)
fun sbuf_advance {cap,n:nat | n <= cap}
  (buf: sized_buf(cap), n: int n): sized_buf(cap - n) = "mac#ptr_add_int"
```

The key insight: if the buffer size changes, only the definition site needs updating. All consumer module constraints and proofs automatically adjust because they reference the `stadef`, not a literal.

**Note**: ATS2 `#define` is dynamic-level only. For type-level constraints (`{tl:nat | tl <= ...}`), use `stadef` instead:

```ats
#define BUFFER_SIZE 4096   (* for runtime C code *)
stadef BUF_CAP = 4096      (* for type-level constraints *)
```

### praxi for connecting proofs to specific values

Use `praxi` (proof axioms) when a proof should only be obtainable through specific known values:

```ats
praxi lemma_attr_class(): VALID_ATTR_NAME(5)   (* "class" *)
praxi lemma_attr_id(): VALID_ATTR_NAME(2)      (* "id" *)
```

These are the ONLY way to obtain `VALID_ATTR_NAME` proofs. Since each praxi maps to a specific known-safe string, arbitrary dynamic data can never produce a proof.

### dataprop vs dataview

- `dataprop` = non-linear (can be unused, duplicated). Use for most proofs.
- `dataview` = linear (must be consumed exactly once). Use when tracking resource ownership (e.g., a buffer lock that must be released).

### Constraint solver limitations

The ATS2 constraint solver handles linear integer arithmetic but NOT case analysis on dataprop constructors. If the solver needs to know that `VALID_ATTR_NAME(n)` implies `n <= 8`, add an explicit constraint alongside the proof parameter:

```ats
fun set_attr
  {nl:nat | nl <= BUF_CAP} {vl:nat | nl + vl <= BUF_CAP}
  (pf_attr: VALID_ATTR_NAME(nl), ..., name_len: int nl, ...): ...
```

The `nl <= BUF_CAP` is redundant with `VALID_ATTR_NAME` (max name is 8 chars) but necessary for the constraint solver.

## Guidelines for Application Code

1. **Prefer ATS over C blocks**: ATS type checking catches proof violations at compile time. C blocks bypass all checking. Write new logic in ATS whenever possible.

2. **Every state transition needs a proof witness**: When changing application state in C code, cite the dataprop constructor in a comment. When in ATS code, construct and consume the proof.

3. **Never modify shared buffers between DOM operations**: If you must read or write a shared buffer between DOM calls, flush pending diffs first.

4. **Async operations require state setup BEFORE the call**: If a function triggers an async bridge operation, all state must be set BEFORE the call, not in a continuation or callback.

5. **Every bug fix must add a preventing proof or invariant**: When fixing a bug, don't just fix the code -- add a dataprop, absprop, or documented structural invariant that makes the same class of bug impossible to reintroduce. If the invariant can be encoded as a dataprop (data values, state transitions, bounds), use a dataprop. If it's structural (recursion shape, continuation pattern), document it as a formal invariant in the `.sats` file with the specific bug class it prevents.

6. **Test failures require dataprop analysis**: Every test failure MUST result in comprehensive analysis of all potential dataprops that could have prevented the failure, followed by implementation of those dataprops. The analysis should identify: (a) what runtime invariant was violated, (b) whether a dataprop/absprop could encode that invariant at compile time, (c) what proof obligations would prevent the same class of failure. Even if the fix is a one-line change, the dataprop analysis and implementation are mandatory.

7. **Errors must be impossible or indicate bad input**: Every error condition must either be (a) made impossible by dependent types / dataprops (compile-time elimination), or (b) the result of invalid external input (corrupt data, malformed input), in which case the user must see a clear visual indication of what was wrong. Console-only logging is never sufficient for user-facing errors.

## Proof Architecture

Proofs are enforced at three levels:

| Level | Mechanism | Example |
|-------|-----------|---------|
| **Enforced** | ATS type system rejects incorrect code | Function requires `VALID_OPCODE` proof |
| **Checked** | Dependent types + `praxi` functions | Function constructs transition proof witness |
| **Documented** | Comments in C code | `app_state = X; // TRANSITION: ...` |

New code should prefer enforced > checked > documented. Move proofs up the hierarchy whenever feasible.
