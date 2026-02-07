(* memory.sats -- Ward: linear memory safety library *)
(* Layered system providing Rust-like guarantees via ATS2 dependent/linear types *)

(* ============================================================
   Layer 1: Sized raw memory with linear ownership
   ============================================================ *)

absvtype raw_own(l:addr, n:int)

fun sized_malloc {n:pos} (n: int n): [l:agz] raw_own(l, n)
fun sized_free {l:agz}{n:nat} (pf: raw_own(l, n)): void

(* Extract pointer value — zero cost *)
fun raw_ptr {l:agz}{n:nat} (pf: !raw_own(l, n)): ptr l

(* ============================================================
   Layer 2: Advance (pointer arithmetic with size tracking)
   ============================================================ *)

fun raw_advance
  {l:agz}{n,m:nat | m <= n}
  (pf: raw_own(l, n), offset: int m)
  : @(raw_own(l, m), raw_own(l+m, n-m))

fun raw_rejoin
  {l:agz}{n,m:nat}
  (left: raw_own(l, n), right: raw_own(l+n, m))
  : raw_own(l, n+m)

(* ============================================================
   Layer 3: Safe memset / memcpy
   ============================================================ *)

fun safe_memset
  {l:agz}{n,cap:nat | n <= cap}
  (pf: !raw_own(l, cap), p: ptr l, c: int, n: int n)
  : void

fun safe_memcpy
  {ld,ls:agz}{n,dcap,scap:nat | n <= dcap; n <= scap}
  (dst_pf: !raw_own(ld, dcap), src_pf: !raw_own(ls, scap),
   dst: ptr ld, src: ptr ls, n: int n)
  : void

(* ============================================================
   Layer 4: Read views (freeze / thaw borrow protocol)
   ============================================================ *)

absvtype raw_frozen(l:addr, n:int, k:int)
absvtype raw_borrow(l:addr, n:int)

fun raw_freeze
  {l:agz}{n:nat}
  (pf: raw_own(l, n))
  : @(raw_frozen(l, n, 1), raw_borrow(l, n))

fun raw_borrow_clone
  {l:agz}{n:nat}{k:pos}
  (frozen: !raw_frozen(l, n, k) >> raw_frozen(l, n, k+1),
   borrow: !raw_borrow(l, n))
  : raw_borrow(l, n)

fun raw_borrow_return
  {l:agz}{n:nat}{k:pos}
  (frozen: !raw_frozen(l, n, k) >> raw_frozen(l, n, k-1),
   borrow: raw_borrow(l, n))
  : void

fun raw_thaw
  {l:agz}{n:nat}
  (frozen: raw_frozen(l, n, 0))
  : raw_own(l, n)

fun raw_borrow_read
  {l:agz}{n:pos}{i:nat | i < n}
  (borrow: !raw_borrow(l, n), p: ptr l, i: int i)
  : int

fun raw_borrow_ptr
  {l:agz}{n:nat}
  (borrow: !raw_borrow(l, n))
  : ptr l

(* ============================================================
   Layer 5: Typed pointers (element-indexed linear arrays)
   ============================================================ *)

absvtype tptr(a:t@ype, l:addr, n:int)

(* Convert raw memory to typed array of n elements.
   Caller must ensure sufficient bytes (n * sizeof(a)).
   The byte count [bytes] is existentially forgotten — the typed
   pointer tracks only element count for bounds checking. *)
fun{a:t@ype}
tptr_init
  {l:agz}{bytes,n:nat}
  (pf: raw_own(l, bytes), p: ptr l, n: int n)
  : tptr(a, l, n)

fun{a:t@ype}
tptr_get
  {l:agz}{n,i:nat | i < n}
  (pf: !tptr(a, l, n), p: ptr l, i: int i)
  : a

fun{a:t@ype}
tptr_set
  {l:agz}{n,i:nat | i < n}
  (pf: !tptr(a, l, n), p: ptr l, i: int i, v: a)
  : void

(* Dissolve typed pointer back to raw ownership. *)
fun{a:t@ype}
tptr_dissolve
  {l:agz}{n:nat}
  (pf: tptr(a, l, n))
  : raw_own(l, n)

fun{a:t@ype}
tptr_ptr
  {l:agz}{n:nat}
  (pf: !tptr(a, l, n))
  : ptr l

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
tptr_borrow_clone
  {l:agz}{n:nat}{k:pos}
  (frozen: !tptr_frozen(a, l, n, k) >> tptr_frozen(a, l, n, k+1),
   borrow: !tptr_borrow(a, l, n))
  : tptr_borrow(a, l, n)

fun{a:t@ype}
tptr_borrow_return
  {l:agz}{n:nat}{k:pos}
  (frozen: !tptr_frozen(a, l, n, k) >> tptr_frozen(a, l, n, k-1),
   borrow: tptr_borrow(a, l, n))
  : void

fun{a:t@ype}
tptr_thaw
  {l:agz}{n:nat}
  (frozen: tptr_frozen(a, l, n, 0))
  : tptr(a, l, n)

fun{a:t@ype}
tptr_borrow_getptr
  {l:agz}{n:nat}
  (borrow: !tptr_borrow(a, l, n))
  : ptr l
