(* promise.dats — Linear promise implementation *)
(* Trusted core. Slot access via $extfcall to ward_slot_get/set. *)
(* Only other C helper: ward_cloref1_invoke for closure calls. *)

#include "share/atspre_staload.hats"
staload "./memory.sats"
staload "./promise.sats"
staload _ = "./memory.dats"

(*
 * Promise layout: 4 pointer-sized slots
 *   [0] = state (0=pending, 1=resolved), cast to/from ptr
 *   [1] = value (resolved value, cast to ptr)
 *   [2] = callback (cloref1 or null)
 *   [3] = chain (downstream promise or null)
 *)

extern fun _ward_malloc_bytes
  (n: int): [l:agz] ptr l = "mac#malloc"

local

assume ward_promise(a, s) = ptr
assume ward_promise_resolver(a) = ptr

in

implement{a}
ward_promise_create() = let
  val p = _ward_malloc_bytes(16)
  val () = $extfcall(void, "memset", p, 0, 16)
in @(p, p) end

implement{a}
ward_promise_resolved(v) = let
  val p = _ward_malloc_bytes(16)
  val () = $extfcall(void, "memset", p, 0, 16)
  val () = $extfcall(void, "ward_slot_set", p, 0, $UNSAFE.cast{ptr}(1))
  val () = $extfcall(void, "ward_slot_set", p, 1,
                     $UNSAFE.castvwtp0{ptr}(v))
in p end

implement{a}
ward_promise_resolve(r, v) = let
  val vp = $UNSAFE.castvwtp0{ptr}(v)
  val () = $extfcall(void, "ward_slot_set", r, 0, $UNSAFE.cast{ptr}(1))
  val () = $extfcall(void, "ward_slot_set", r, 1, vp)
  val cb = $extfcall(ptr, "ward_slot_get", r, 2)
  val chain = $extfcall(ptr, "ward_slot_get", r, 3)
in
  if $UNSAFE.cast{int}(cb) > 0 then
    if $UNSAFE.cast{int}(chain) > 0 then let
      val result = $extfcall(ptr, "ward_cloref1_invoke", cb, vp)
      val () = $extfcall(void, "ward_slot_set", chain, 0, $UNSAFE.cast{ptr}(1))
      val () = $extfcall(void, "ward_slot_set", chain, 1, result)
    in () end
    else ()
  else ()
end

implement{a}
ward_promise_extract(p) = let
  val vp = $extfcall(ptr, "ward_slot_get", p, 1)
  val () = $extfcall(void, "free", p)
in $UNSAFE.castvwtp0{a}(vp) end

implement{a}{s}
ward_promise_discard(p) = $extfcall(void, "free", p)

implement{a}{b}
ward_promise_then(p, f) = let
  val chain = _ward_malloc_bytes(16)
  val () = $extfcall(void, "memset", chain, 0, 16)
  val () = $extfcall(void, "ward_slot_set", p, 2,
                     $UNSAFE.castvwtp0{ptr}(f))
  val () = $extfcall(void, "ward_slot_set", p, 3, chain)
in chain end

end (* local *)
