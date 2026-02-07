(* memory.dats -- Ward: linear memory safety implementations *)
(* The "unsafe core" that the type system protects users from touching. *)
(* At runtime all proofs are erased — zero overhead. *)

#include "share/atspre_staload.hats"
staload "./memory.sats"

local

  assume raw_own(l, n) = ptr l
  assume raw_frozen(l, n, k) = ptr l
  assume raw_borrow(l, n) = ptr l
  assume tptr(a, l, n) = ptr l
  assume tptr_frozen(a, l, n, k) = ptr l
  assume tptr_borrow(a, l, n) = ptr l

in

(* ============================================================
   Layers 1-4: Raw memory
   ============================================================ *)

extern fun _ward_malloc {n:pos} (n: int n): [l:agz] ptr l = "mac#malloc"
extern fun _ward_ptr_add {l:addr}{m:nat} (p: ptr l, m: int m): ptr(l+m) = "mac#ward_ptr_add"

implement sized_malloc{n}(n) = _ward_malloc(n)

implement sized_free{l}{n}(pf) =
  $extfcall(void, "free", pf)

implement raw_ptr{l}{n}(pf) = pf

implement raw_advance{l}{n,m}(pf, offset) = let
  val suffix = _ward_ptr_add(pf, offset)
in
  @(pf, suffix)
end

implement raw_rejoin{l}{n,m}(left, right) = left

implement safe_memset{l}{n,cap}(pf, p, c, n) =
  $extfcall(void, "memset", p, c, n)

implement safe_memcpy{ld,ls}{n,dcap,scap}
  (dst_pf, src_pf, dst, src, n) =
  $extfcall(void, "memcpy", dst, src, n)

implement raw_freeze{l}{n}(pf) = @(pf, pf)

implement raw_borrow_clone{l}{n}{k}(frozen, borrow) = borrow

implement raw_borrow_return{l}{n}{k}(frozen, borrow) = ()

implement raw_thaw{l}{n}(frozen) = frozen

implement raw_borrow_read{l}{n}{i}(borrow, p, i) =
  $UNSAFE.ptr0_get<int>(_ward_ptr_add(p, i))

implement raw_borrow_ptr{l}{n}(borrow) = borrow

(* ============================================================
   Layers 5-6: Typed pointers
   ============================================================ *)

implement{a}
tptr_init{l}{bytes,n}(pf, p, n) = let
  val nbytes = n * sz2i(sizeof<a>)
  val () = $extfcall(void, "memset", p, 0, nbytes)
in
  pf
end

implement{a}
tptr_get{l}{n,i}(pf, p, i) =
  $UNSAFE.ptr0_get<a>(ptr_add<a>(p, i))

implement{a}
tptr_set{l}{n,i}(pf, p, i, v) =
  $UNSAFE.ptr0_set<a>(ptr_add<a>(p, i), v)

implement{a}
tptr_dissolve{l}{n}(pf) = pf

implement{a}
tptr_ptr{l}{n}(pf) = pf

implement{a}
tptr_freeze{l}{n}(pf) = @(pf, pf)

implement{a}
tptr_borrow_get{l}{n,i}(borrow, p, i) =
  $UNSAFE.ptr0_get<a>(ptr_add<a>(p, i))

implement{a}
tptr_borrow_clone{l}{n}{k}(frozen, borrow) = borrow

implement{a}
tptr_borrow_return{l}{n}{k}(frozen, borrow) = ()

implement{a}
tptr_thaw{l}{n}(frozen) = frozen

implement{a}
tptr_borrow_getptr{l}{n}(borrow) = borrow

end (* local *)
