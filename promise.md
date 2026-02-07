# Linear Promises for ATS2

## Overview

A promise system for ATS2 that leverages linear types to enforce correct usage at compile time and dependent types to encode resolution state. Promises are first-class linear values that must be consumed exactly once. Errors are handled through algebraic `Result` types rather than separate error channels.

## Core Types

```ats2
(* Resolution state index *)
datasort PromiseState =
  | Pending
  | Resolved

(* Result type for resolved values *)
datatype Result(a: t@ype, e: t@ype) =
  | Ok(a, e) of a
  | Err(a, e) of e

(* Linear promise indexed by state *)
absvtype Promise(a: t@ype, e: t@ype, s: PromiseState)

(* Resolver: the write end of a promise. Also linear — must be used exactly once. *)
absvtype Resolver(a: t@ype, e: t@ype)

(* Convenience aliases *)
vtypedef PendingPromise(a: t@ype, e: t@ype) = Promise(a, e, Pending)
vtypedef ResolvedPromise(a: t@ype, e: t@ype) = Promise(a, e, Resolved)
```

## Creation

Creating a promise yields a linear pair: the promise (read end) and the resolver (write end). Both are linear and must be consumed exactly once. The resolver is consumed by resolving or rejecting. The promise is consumed by attaching a callback or extracting the value.

```ats2
(* Create a promise/resolver pair *)
fun {a: t@ype} {e: t@ype}
promise_create(): (PendingPromise(a, e), Resolver(a, e))

(* Create an already-resolved promise *)
fun {a: t@ype} {e: t@ype}
promise_resolved(v: a): ResolvedPromise(a, e)

(* Create an already-rejected promise *)
fun {a: t@ype} {e: t@ype}
promise_rejected(err: e): ResolvedPromise(a, e)
```

## Resolution

The resolver is consumed by exactly one of these operations. After resolution, the resolver no longer exists — double-resolution is a compile-time error.

```ats2
(* Consume the resolver by providing a value *)
fun {a: t@ype} {e: t@ype}
resolve(r: Resolver(a, e), v: a): void

(* Consume the resolver by providing an error *)
fun {a: t@ype} {e: t@ype}
reject(r: Resolver(a, e), err: e): void

(* Consume the resolver by providing a Result directly *)
fun {a: t@ype} {e: t@ype}
settle(r: Resolver(a, e), res: Result(a, e)): void
```

## Consumption

A promise must be consumed. The primary consumption mechanism is `then`, which transforms a pending promise into a new pending promise — the callback fires when the original resolves.

```ats2
(* Attach a callback. Consumes the input promise, returns a new promise. *)
fun {a: t@ype} {b: t@ype} {e: t@ype}
then(
  p: PendingPromise(a, e),
  f: Result(a, e) -<cloref1> Result(b, e)
): PendingPromise(b, e)

(* Map over the success value only *)
fun {a: t@ype} {b: t@ype} {e: t@ype}
map(
  p: PendingPromise(a, e),
  f: a -<cloref1> b
): PendingPromise(b, e)

(* Map over the error value only *)
fun {a: t@ype} {e1: t@ype} {e2: t@ype}
map_err(
  p: PendingPromise(a, e1),
  f: e1 -<cloref1> e2
): PendingPromise(a, e2)

(* Flat map — callback returns a new promise *)
fun {a: t@ype} {b: t@ype} {e: t@ype}
flat_map(
  p: PendingPromise(a, e),
  f: a -<cloref1> PendingPromise(b, e)
): PendingPromise(b, e)

(* Consume a resolved promise by extracting its value *)
fun {a: t@ype} {e: t@ype}
promise_extract(p: ResolvedPromise(a, e)): Result(a, e)

(* Consume a promise by discarding it (e.g., fire-and-forget).
   This is the only way to explicitly drop a promise without
   extracting or chaining. Makes the intent visible. *)
fun {a: t@ype} {e: t@ype} {s: PromiseState}
promise_discard(p: Promise(a, e, s)): void
```

## Combinators

Combinators consume multiple promises and produce a single promise. Each input promise is consumed linearly — after passing a promise to a combinator, it cannot be used again.

```ats2
(* Wait for all promises. Consumes a linear list of promises,
   produces a promise of a list of results.
   If any reject, the combined promise resolves with the collected
   results (including errors). *)
fun {a: t@ype} {e: t@ype} {n: nat}
promise_all(
  ps: list_vt(PendingPromise(a, e), n)
): PendingPromise(list(Result(a, e), n), e)

(* Wait for all to succeed. If any fails, short-circuit with
   the first error. Remaining promises are discarded. *)
fun {a: t@ype} {e: t@ype} {n: nat}
promise_all_ok(
  ps: list_vt(PendingPromise(a, e), n)
): PendingPromise(list(a, n), e)

(* First to resolve wins. Remaining promises are discarded. *)
fun {a: t@ype} {e: t@ype} {n: pos}
promise_race(
  ps: list_vt(PendingPromise(a, e), n)
): PendingPromise(a, e)

(* Combine two promises of different types *)
fun {a: t@ype} {b: t@ype} {e: t@ype}
promise_join(
  pa: PendingPromise(a, e),
  pb: PendingPromise(b, e)
): PendingPromise((a, b), e)
```

Note: `promise_all` encodes the list length `n` in the return type. The dependent type guarantees you get back exactly as many results as promises you provided.

## Error Recovery

```ats2
(* Recover from errors — like a catch block *)
fun {a: t@ype} {e: t@ype}
promise_recover(
  p: PendingPromise(a, e),
  f: e -<cloref1> a
): PendingPromise(a, e)

(* Recover with a new promise — like flat_map for errors *)
fun {a: t@ype} {e: t@ype}
promise_recover_with(
  p: PendingPromise(a, e),
  f: e -<cloref1> PendingPromise(a, e)
): PendingPromise(a, e)
```

## Event Loop Integration

The promise system requires an event loop to drive resolution. The event loop is a linear resource itself — there is exactly one, and it must be threaded through the program.

```ats2
(* Linear event loop *)
absvtype EventLoop

(* Create and run the event loop *)
fun eventloop_create(): EventLoop
fun eventloop_run(loop: !EventLoop): void
fun eventloop_destroy(loop: EventLoop): void

(* Schedule a callback on the event loop *)
fun eventloop_defer(
  loop: !EventLoop,
  f: () -<cloref1> void
): void

(* Register I/O interest — returns a promise that resolves
   when the fd is ready *)
fun eventloop_read_ready(
  loop: !EventLoop,
  fd: int
): PendingPromise(void, IOError)

fun eventloop_write_ready(
  loop: !EventLoop,
  fd: int
): PendingPromise(void, IOError)

(* Timer — resolves after delay *)
fun eventloop_delay(
  loop: !EventLoop,
  seconds: double
): PendingPromise(void, void)
```

The `!EventLoop` notation means the event loop is borrowed, not consumed — these functions use it without taking ownership.

## What the Type Checker Enforces

The following bugs are compile-time errors:

1. **Forgetting to handle a promise.** A `PendingPromise` is linear — if you don't chain, extract, or explicitly discard it, the program won't compile.

2. **Resolving twice.** The `Resolver` is linear and consumed by `resolve` or `reject`. A second call has no resolver to consume.

3. **Forgetting to resolve.** The `Resolver` is linear. If a code path drops it without calling `resolve`, `reject`, or `settle`, the program won't compile.

4. **Using a promise after chaining.** `then` consumes the input promise. Any subsequent use of that binding is a compile-time error.

5. **Extracting from a pending promise.** `promise_extract` only accepts `ResolvedPromise`. A `PendingPromise` is a different type at the index level.

6. **Mismatched result counts.** `promise_all` on a list of length `n` returns a promise of a list of length `n`. The dependent type makes off-by-one errors unrepresentable.

## What the Type Checker Does Not Enforce

Some properties remain runtime concerns:

1. **Deadlock.** If promise A waits on promise B which waits on promise A, this is not caught statically. (This would require an effect system or more sophisticated static analysis.)

2. **Starvation.** The event loop scheduling policy is not encoded in the types.

3. **Callback termination.** A callback passed to `then` could loop forever.

## Design Rationale

**Why promises over async/await?** Async/await is syntactic sugar that hides the promise lifecycle. In ATS2, the explicit lifecycle is the point — it's what the linear type checker reasons about. Adding async/await would obscure the very structure that makes the system safe.

**Why `Result(a, e)` over separate error channels?** Twisted's dual callback/errback chains were a persistent source of bugs — forgotten errbacks, accidentally swallowed errors, unclear error propagation through chains. An algebraic `Result` with exhaustive pattern matching eliminates this class of bug entirely. You cannot forget to handle the error case because the compiler won't let you do a non-exhaustive match.

**Why a linear event loop?** Making the event loop linear prevents accidentally creating two (which would split I/O handling) and ensures it is properly shut down. The `!` borrow syntax lets functions use it without consuming it, which is the common case.

**Why `promise_discard`?** In a linear type system, you can't silently drop values. Fire-and-forget is a legitimate pattern, but it should be explicit. A bare `promise_discard` in a code review is a signal worth examining.
