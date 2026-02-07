(* memory.dats -- Ward: linear memory safety implementations *)
(* The "unsafe core" that the type system protects users from touching. *)
(* At runtime all proofs are erased — zero overhead. *)

#include "share/atspre_staload.hats"
staload "./memory.sats"

local

  assume ward_own(l, n) = ptr l
  assume ward_frozen(l, n, k) = ptr l
  assume ward_borrow(l, n) = ptr l
  assume ward_arr(a, l, n) = ptr l
  assume ward_arr_frozen(a, l, n, k) = ptr l
  assume ward_arr_borrow(a, l, n) = ptr l

in

(* ============================================================
   Layers 1-4: Raw memory
   ============================================================ *)

extern fun _ward_malloc {n:pos} (n: int n): [l:agz] ptr l = "mac#malloc"
extern fun _ward_ptr_add {l:addr}{m:nat} (p: ptr l, m: int m): ptr(l+m) = "mac#ward_ptr_add"

implement ward_malloc{n}(n) = _ward_malloc(n)

implement ward_free{l}{n}(own) =
  $extfcall(void, "free", own)

implement ward_split{l}{n,m}(own, m) = let
  val tail = _ward_ptr_add(own, m)
in
  @(own, tail)
end

implement ward_join{l}{n,m}(left, right) = left

implement ward_memset{l}{n,cap}(own, c, n) =
  $extfcall(void, "memset", own, c, n)

implement ward_memcpy{ld,ls}{n,dcap,scap}(dst, src, n) =
  $extfcall(void, "memcpy", dst, src, n)

implement ward_freeze{l}{n}(own) = @(own, own)

implement ward_thaw{l}{n}(frozen) = frozen

implement ward_dup{l}{n}{k}(frozen, borrow) = borrow

implement ward_drop{l}{n}{k}(frozen, borrow) = ()

implement ward_read{l}{n}{i}(borrow, i) =
  $UNSAFE.ptr0_get<int>(_ward_ptr_add(borrow, i))

(* ============================================================
   Layers 5-6: Typed arrays
   ============================================================ *)

implement{a}
ward_arr_init{l}{bytes,n}(own, n) = let
  val nbytes = n * sz2i(sizeof<a>)
  val () = $extfcall(void, "memset", own, 0, nbytes)
in
  own
end

implement{a}
ward_arr_get{l}{n,i}(arr, i) =
  $UNSAFE.ptr0_get<a>(ptr_add<a>(arr, i))

implement{a}
ward_arr_set{l}{n,i}(arr, i, v) =
  $UNSAFE.ptr0_set<a>(ptr_add<a>(arr, i), v)

implement{a}
ward_arr_fini{l}{n}(arr) = arr

implement{a}
ward_arr_freeze{l}{n}(arr) = @(arr, arr)

implement{a}
ward_arr_thaw{l}{n}(frozen) = frozen

implement{a}
ward_arr_dup{l}{n}{k}(frozen, borrow) = borrow

implement{a}
ward_arr_drop{l}{n}{k}(frozen, borrow) = ()

implement{a}
ward_arr_read{l}{n,i}(borrow, i) =
  $UNSAFE.ptr0_get<a>(ptr_add<a>(borrow, i))

end (* local *)
