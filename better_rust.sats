(* better_rust.sats -- Static declarations for sized linear pointers *)

(* ============================================================
   Layer 1: Sized raw memory with linear ownership
   ============================================================ *)

(* Abstract view: proof that we own [n] bytes at address [l] *)
absvtype raw_own(l:addr, n:int)

(* Allocate n bytes, get back a linear proof of ownership *)
fun sized_malloc
  {n:pos}
  (n: int n)
  : [l:agz] raw_own(l, n)

(* Free — must own the full allocation.
   In practice you'd track the original size; simplified here. *)
fun sized_free
  {l:agz}{n:nat}
  (pf: raw_own(l, n))
  : void

(* ============================================================
   Layer 2: Advance (pointer arithmetic with size tracking)
   ============================================================ *)

(* Advance consumes the old ownership, returns two pieces:
   - ownership of the prefix (which we "split off")
   - ownership of the suffix (the advanced pointer)
   This is key: the split is *linear*, so no double-free. *)
fun raw_advance
  {l:agz}{n,m:nat | m <= n}
  (pf: raw_own(l, n), offset: int m)
  : @(raw_own(l, m), raw_own(l+m, n-m))

(* Rejoin two adjacent regions *)
fun raw_rejoin
  {l:agz}{n,m:nat}
  (left: raw_own(l, n), right: raw_own(l+n, m))
  : raw_own(l, n+m)

(* ============================================================
   Layer 3: Safe memset / memcpy wrappers
   ============================================================ *)

(* memset: requires proof you own at least [n] bytes *)
fun safe_memset
  {l:agz}{n,cap:nat | n <= cap}
  (pf: !raw_own(l, cap), p: ptr l, c: int, n: size_t n)
  : void

(* memcpy: src and dst must both have sufficient size.
   Note: linearity of dst prevents src==dst aliasing when
   both are raw_own. *)
fun safe_memcpy
  {ld,ls:agz}{n,dcap,scap:nat | n <= dcap; n <= scap}
  (dst_pf: !raw_own(ld, dcap),
   src_pf: !raw_own(ls, scap),
   dst: ptr ld, src: ptr ls,
   n: size_t n)
  : void

(* ============================================================
   Layer 4: Read views (borrow semantics)
   ============================================================ *)

(* A read view is a non-linear (copyable) proof of read access.
   The trick: creating one "locks" the raw_own into a frozen state.
   You get it back only by consuming all read views. *)

(* Frozen ownership: you gave out [k] read borrows *)
absvtype raw_frozen(l:addr, n:int, k:int)

(* A read borrow token — one outstanding shared reference *)
absvtype raw_borrow(l:addr, n:int)

(* Freeze: convert mutable ownership into frozen + one read borrow *)
fun raw_freeze
  {l:agz}{n:nat}
  (pf: raw_own(l, n))
  : @(raw_frozen(l, n, 1), raw_borrow(l, n))

(* Clone a read borrow (increases the borrow count) *)
fun raw_borrow_clone
  {l:agz}{n:nat}{k:pos}
  (frozen: !raw_frozen(l, n, k) >> raw_frozen(l, n, k+1),
   borrow: !raw_borrow(l, n))
  : raw_borrow(l, n)

(* Return a read borrow (decreases the borrow count) *)
fun raw_borrow_return
  {l:agz}{n:nat}{k:pos}
  (frozen: !raw_frozen(l, n, k) >> raw_frozen(l, n, k-1),
   borrow: raw_borrow(l, n))  // consumed!
  : void

(* Thaw: convert frozen back to mutable — only when borrow count is 0 *)
fun raw_thaw
  {l:agz}{n:nat}
  (frozen: raw_frozen(l, n, 0))
  : raw_own(l, n)

(* Read through a borrow *)
fun raw_borrow_read
  {l:agz}{n:nat}
  (borrow: !raw_borrow(l, n), p: ptr l, offset: size_t 0)
  : byte

(* ============================================================
   Layer 5: Typed pointers
   ============================================================ *)

(* Abstract: a typed, initialized, linear pointer to [n] values of type [a] *)
absvtype tptr(a:t@ype, l:addr, n:int)

(* Convert raw memory to typed: performs memset(0) as initialization.
   Requires that n is a multiple of sizeof(a). *)
fun{a:t@ype}
tptr_init
  {l:agz}{n:nat}
  (pf: raw_own(l, n * sizeof(a)), p: ptr l, n: int n)
  : tptr(a, l, n)

(* Read element at index — bounds-checked at compile time *)
fun{a:t@ype}
tptr_get
  {l:agz}{n,i:nat | i < n}
  (pf: !tptr(a, l, n), p: ptr l, i: int i)
  : a

(* Write element at index — bounds-checked at compile time *)
fun{a:t@ype}
tptr_set
  {l:agz}{n,i:nat | i < n}
  (pf: !tptr(a, l, n), p: ptr l, i: int i, v: a)
  : void

(* Dissolve typed pointer back to raw (e.g., for reuse or free) *)
fun{a:t@ype}
tptr_dissolve
  {l:agz}{n:nat}
  (pf: tptr(a, l, n))
  : raw_own(l, n * sizeof(a))

(* ============================================================
   Layer 6: Typed borrows (read-only shared access to typed data)
   ============================================================ *)

absvtype tptr_frozen(a:t@ype, l:addr, n:int, k:int)
absvtype tptr_borrow(a:t@ype, l:addr, n:int)

fun{a:t@ype}
tptr_freeze
  {l:agz}{n:nat}
  (pf: tptr(a, l, n))
  : @(tptr_frozen(a, l, n, 1), tptr_borrow(a, l, n))

fun{a:t@ype}
tptr_borrow_get
  {l:agz}{n,i:nat | i < n}
  (borrow: !tptr_borrow(a, l, n), p: ptr l, i: int i)
  : a

fun{a:t@ype}
tptr_thaw
  {l:agz}{n:nat}
  (frozen: tptr_frozen(a, l, n, 0))
  : tptr(a, l, n)
