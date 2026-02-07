(* memory.sats -- Ward: linear memory safety library *)
(* All functions prefixed ward_ for easy auditing. *)
(* No raw pointer extraction — safety guarantees are inescapable. *)

(* ============================================================
   Types
   ============================================================ *)

absvtype ward_own(l:addr, n:int)
absvtype ward_frozen(l:addr, n:int, k:int)
absvtype ward_borrow(l:addr, n:int)
absvtype ward_arr(a:t@ype, l:addr, n:int)
absvtype ward_arr_frozen(a:t@ype, l:addr, n:int, k:int)
absvtype ward_arr_borrow(a:t@ype, l:addr, n:int)

(* ============================================================
   Layer 1: Sized raw memory with linear ownership
   ============================================================ *)

fun ward_malloc {n:pos} (n: int n): [l:agz] ward_own(l, n)
fun ward_free {l:agz}{n:nat} (own: ward_own(l, n)): void

(* ============================================================
   Layer 2: Split / join (pointer arithmetic with size tracking)
   ============================================================ *)

fun ward_split
  {l:agz}{n,m:nat | m <= n}
  (own: ward_own(l, n), m: int m)
  : @(ward_own(l, m), ward_own(l+m, n-m))

fun ward_join
  {l:agz}{n,m:nat}
  (left: ward_own(l, n), right: ward_own(l+n, m))
  : ward_own(l, n+m)

(* ============================================================
   Layer 3: Memory operations (bounds-checked)
   ============================================================ *)

fun ward_memset
  {l:agz}{n,cap:nat | n <= cap}
  (own: !ward_own(l, cap), c: int, n: int n)
  : void

fun ward_memcpy
  {ld,ls:agz}{n,dcap,scap:nat | n <= dcap; n <= scap}
  (dst: !ward_own(ld, dcap), src: !ward_borrow(ls, scap), n: int n)
  : void

(* Single-byte access to owned memory (bounds-checked).
   Consume and return ownership — implemented via split/join. *)
fun ward_peek
  {l:agz}{n:pos}{i:nat | i < n}
  (own: ward_own(l, n), i: int i)
  : @(int, ward_own(l, n))

fun ward_poke
  {l:agz}{n:pos}{i:nat | i < n}
  (own: ward_own(l, n), i: int i, v: int)
  : ward_own(l, n)

(* ============================================================
   Layer 4: Freeze / thaw borrow protocol
   ============================================================ *)

fun ward_freeze
  {l:agz}{n:nat}
  (own: ward_own(l, n))
  : @(ward_frozen(l, n, 1), ward_borrow(l, n))

fun ward_thaw
  {l:agz}{n:nat}
  (frozen: ward_frozen(l, n, 0))
  : ward_own(l, n)

fun ward_dup
  {l:agz}{n:nat}{k:pos}
  (frozen: !ward_frozen(l, n, k) >> ward_frozen(l, n, k+1),
   borrow: !ward_borrow(l, n))
  : ward_borrow(l, n)

fun ward_drop
  {l:agz}{n:nat}{k:pos}
  (frozen: !ward_frozen(l, n, k) >> ward_frozen(l, n, k-1),
   borrow: ward_borrow(l, n))
  : void

fun ward_read
  {l:agz}{n:pos}{i:nat | i < n}
  (borrow: !ward_borrow(l, n), i: int i)
  : int

fun ward_borrow_split
  {l:agz}{n,m:nat | m <= n}{k:pos}
  (frozen: !ward_frozen(l, n, k) >> ward_frozen(l, n, k+1),
   borrow: ward_borrow(l, n), m: int m)
  : @(ward_borrow(l, m), ward_borrow(l+m, n-m))

fun ward_borrow_join
  {l:agz}{n,m:nat}{k:int | k > 1}
  (frozen: !ward_frozen(l, n+m, k) >> ward_frozen(l, n+m, k-1),
   left: ward_borrow(l, n), right: ward_borrow(l+n, m))
  : ward_borrow(l, n+m)

(* ============================================================
   Layer 5: Typed arrays (element-indexed linear arrays)
   ============================================================ *)

(* Allocate and zero-initialize a typed array of n elements.
   Computes n * sizeof(a) internally — no size mismatch possible. *)
fun{a:t@ype}
ward_arr_alloc
  {n:pos}
  (n: int n)
  : [l:agz] ward_arr(a, l, n)

fun{a:t@ype}
ward_arr_get
  {l:agz}{n,i:nat | i < n}
  (arr: !ward_arr(a, l, n), i: int i)
  : a

fun{a:t@ype}
ward_arr_set
  {l:agz}{n,i:nat | i < n}
  (arr: !ward_arr(a, l, n), i: int i, v: a)
  : void

(* Free a typed array. *)
fun{a:t@ype}
ward_arr_free
  {l:agz}{n:nat}
  (arr: ward_arr(a, l, n))
  : void

(* ============================================================
   Layer 6: Typed borrows (read-only shared access to typed data)
   ============================================================ *)

fun{a:t@ype}
ward_arr_freeze
  {l:agz}{n:nat}
  (arr: ward_arr(a, l, n))
  : @(ward_arr_frozen(a, l, n, 1), ward_arr_borrow(a, l, n))

fun{a:t@ype}
ward_arr_thaw
  {l:agz}{n:nat}
  (frozen: ward_arr_frozen(a, l, n, 0))
  : ward_arr(a, l, n)

fun{a:t@ype}
ward_arr_dup
  {l:agz}{n:nat}{k:pos}
  (frozen: !ward_arr_frozen(a, l, n, k) >> ward_arr_frozen(a, l, n, k+1),
   borrow: !ward_arr_borrow(a, l, n))
  : ward_arr_borrow(a, l, n)

fun{a:t@ype}
ward_arr_drop
  {l:agz}{n:nat}{k:pos}
  (frozen: !ward_arr_frozen(a, l, n, k) >> ward_arr_frozen(a, l, n, k-1),
   borrow: ward_arr_borrow(a, l, n))
  : void

fun{a:t@ype}
ward_arr_read
  {l:agz}{n,i:nat | i < n}
  (borrow: !ward_arr_borrow(a, l, n), i: int i)
  : a
