(* memory.sats -- Ward: linear memory safety library *)
(* All functions prefixed ward_ for easy auditing. *)
(* No raw pointer extraction — safety guarantees are inescapable. *)

(* ============================================================
   Layer 1: Sized raw memory with linear ownership
   ============================================================ *)

absvtype ward_own(l:addr, n:int)

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
   Layer 3: Safe memset / memcpy
   ============================================================ *)

fun ward_memset
  {l:agz}{n,cap:nat | n <= cap}
  (own: !ward_own(l, cap), c: int, n: int n)
  : void

fun ward_memcpy
  {ld,ls:agz}{n,dcap,scap:nat | n <= dcap; n <= scap}
  (dst: !ward_own(ld, dcap), src: !ward_own(ls, scap), n: int n)
  : void

(* ============================================================
   Layer 4: Freeze / thaw borrow protocol
   ============================================================ *)

absvtype ward_frozen(l:addr, n:int, k:int)
absvtype ward_borrow(l:addr, n:int)

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

(* ============================================================
   Layer 5: Typed arrays (element-indexed linear arrays)
   ============================================================ *)

absvtype ward_arr(a:t@ype, l:addr, n:int)

(* Convert raw memory to typed array of n elements.
   Caller must ensure sufficient bytes (n * sizeof(a)).
   The byte count is existentially forgotten — the typed
   array tracks only element count for bounds checking. *)
fun{a:t@ype}
ward_arr_init
  {l:agz}{bytes,n:nat}
  (own: ward_own(l, bytes), n: int n)
  : ward_arr(a, l, n)

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

(* Dissolve typed array back to raw ownership. *)
fun{a:t@ype}
ward_arr_fini
  {l:agz}{n:nat}
  (arr: ward_arr(a, l, n))
  : ward_own(l, n)

(* ============================================================
   Layer 6: Typed borrows (read-only shared access to typed data)
   ============================================================ *)

absvtype ward_arr_frozen(a:t@ype, l:addr, n:int, k:int)
absvtype ward_arr_borrow(a:t@ype, l:addr, n:int)

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
