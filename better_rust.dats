(* better_rust.dats -- Implementations + usage demo *)

#include "share/atspre_staload.hats"
staload "./better_rust.sats"

(* ============================================================
   Implementations: these are the "unsafe core" that the
   type system protects users from ever needing to touch.
   ============================================================ *)

(* For the prototype, raw_own is implemented as a phantomly-typed
   pointer. At runtime it's erased — zero overhead. *)

local

  assume raw_own(l, n) = ptr l
  assume raw_frozen(l, n, k) = ptr l
  assume raw_borrow(l, n) = ptr l

in

implement sized_malloc{n}(n) = let
  val p = $extfcall(ptr, "malloc", n)
  (* In production: check for null *)
in
  p
end

implement sized_free{l}{n}(pf) =
  $extfcall(void, "free", pf)

implement raw_advance{l}{n,m}(pf, offset) = let
  val suffix = ptr_add<byte>(pf, offset)
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

implement raw_borrow_read{l}{n}(borrow, p, offset) =
  $UNSAFE.ptr0_get<byte>(p)

end (* local *)

(* ============================================================
   Typed pointer implementations
   ============================================================ *)

local

  assume tptr(a, l, n) = ptr l
  assume tptr_frozen(a, l, n, k) = ptr l
  assume tptr_borrow(a, l, n) = ptr l

in

implement{a}
tptr_init{l}{n}(pf, p, n) = let
  val () = safe_memset(pf, p, 0, i2sz(n * sz2i(sizeof<a>)))
in
  p
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
tptr_freeze{l}{n}(pf) = @(pf, pf)

implement{a}
tptr_borrow_get{l}{n,i}(borrow, p, i) =
  $UNSAFE.ptr0_get<a>(ptr_add<a>(p, i))

implement{a}
tptr_thaw{l}{n}(frozen) = frozen

end (* local *)

(* ============================================================
   Demo: the whole point
   ============================================================ *)

implement main0() = let

  (* --- Allocate 40 bytes, get linear ownership proof --- *)
  val raw = sized_malloc(40)

  (* --- Split: first 16 bytes and remaining 24 --- *)
  val @(prefix, suffix) = raw_advance(raw, 16)

  (* --- Safe memset on the prefix: compiler KNOWS 16 >= 16 --- *)
  val () = safe_memset(prefix, addr@prefix, 0, i2sz(16))

  (* This would be a compile error:
     safe_memset(prefix, addr@prefix, 0, i2sz(20))
     because 20 > 16. The dependent type catches it. *)

  (* --- Rejoin and free --- *)
  val whole = raw_rejoin(prefix, suffix)
  val () = sized_free(whole)

  (* --- Typed pointer demo --- *)
  val raw2 = sized_malloc(40)

  (* Interpret as 10 ints (assuming 4-byte int) *)
  val tp = tptr_init<int>(raw2, addr@raw2, 10)

  (* Bounds-checked write: index 5 of 10 — ok *)
  val () = tptr_set<int>(tp, addr@tp, 5, 42)

  (* Bounds-checked read *)
  val v = tptr_get<int>(tp, addr@tp, 5)
  val () = println!("tp[5] = ", v)  // prints 42

  (* This would be a compile error:
     val v = tptr_get<int>(tp, addr@tp, 10)
     because 10 is not < 10. *)

  (* --- Borrow demo --- *)
  val @(frozen, borrow1) = tptr_freeze<int>(tp)

  (* Can read through the borrow *)
  val v2 = tptr_borrow_get<int>(borrow1, addr@borrow1, 5)
  val () = println!("borrowed read: ", v2)

  (* Can't write! tp is frozen. No tptr_set is possible because
     we don't have a tptr anymore — we have a tptr_frozen.
     The type system enforces this without any runtime check. *)

  (* Return the borrow, thaw, get mutable access back *)
  // For this prototype, manually manage the borrow count
  // In a real version, the frozen type tracks this dependently
  val () = let
    prval () = $UNSAFE.cast2void(borrow1)
  in end
  val tp2 = tptr_thaw<int>($UNSAFE.castvwtp0{tptr_frozen(int,_,_,0)}(frozen))

  (* Now we can write again *)
  val () = tptr_set<int>(tp2, addr@tp2, 5, 99)
  val v3 = tptr_get<int>(tp2, addr@tp2, 5)
  val () = println!("after thaw, tp[5] = ", v3)

  (* Clean up *)
  val raw_back = tptr_dissolve<int>(tp2)
  val () = sized_free(raw_back)

in end
