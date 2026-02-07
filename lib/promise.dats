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

(*
 * $UNSAFE justifications — each use is marked with its pattern tag.
 *
 * [U1] castvwtp0{ptr}(v) and castvwtp0{a}(vp) (resolved, resolve, extract, then):
 *   Erases/recovers typed value a to/from ptr for storage in pointer-sized slots.
 *   Alternative considered: use ward_arr<ptr> for the 4 slots, replacing
 *   $extfcall slot access with safe ward_arr_get/set.
 *   Rejected: ward_arr introduces existential [l:addr] that cannot be
 *   unified with assume ward_promise(a,s) at type-assume time. Even if it
 *   could, the a<->ptr erasure casts remain unavoidable — the slot type
 *   is ptr but the stored values are heterogeneous (a, closure, chain ptr).
 *
 * [U2] cast{ptr}(1) (resolved, resolve):
 *   Stores integer state flag (1=resolved) in a ptr-sized slot.
 *   Inherent to the slot layout: all 4 fields are ptr-sized. No way to
 *   store an int in a ptr slot without a cast.
 *
 * [U3] cast{int}(cb), cast{int}(chain) (resolve):
 *   Null-checks on ptr values retrieved from slots.
 *   Alternative considered: ptr_isnot_null from ATS2 prelude.
 *   Rejected: unavailable in freestanding mode (_ATS_CCOMP_PRELUDE_NONE_).
 *)

implement{a}
ward_promise_create() = let
  val p = _ward_malloc_bytes(16)
  val () = $extfcall(void, "memset", p, 0, 16)
in @(p, p) end

implement{a}
ward_promise_resolved(v) = let
  val p = _ward_malloc_bytes(16)
  val () = $extfcall(void, "memset", p, 0, 16)
  val () = $extfcall(void, "ward_slot_set", p, 0, $UNSAFE.cast{ptr}(1)) (* [U2] *)
  val () = $extfcall(void, "ward_slot_set", p, 1,
                     $UNSAFE.castvwtp0{ptr}(v)) (* [U1] *)
in p end

implement{a}
ward_promise_resolve(r, v) = let
  val vp = $UNSAFE.castvwtp0{ptr}(v) (* [U1] *)
  val () = $extfcall(void, "ward_slot_set", r, 0, $UNSAFE.cast{ptr}(1)) (* [U2] *)
  val () = $extfcall(void, "ward_slot_set", r, 1, vp)
  val cb = $extfcall(ptr, "ward_slot_get", r, 2)
  val chain = $extfcall(ptr, "ward_slot_get", r, 3)
in
  if $UNSAFE.cast{int}(cb) > 0 then (* [U3] *)
    if $UNSAFE.cast{int}(chain) > 0 then let (* [U3] *)
      val result = $extfcall(ptr, "ward_cloref1_invoke", cb, vp)
      val () = $extfcall(void, "ward_slot_set", chain, 0, $UNSAFE.cast{ptr}(1)) (* [U2] *)
      val () = $extfcall(void, "ward_slot_set", chain, 1, result)
    in () end
    else ()
  else ()
end

implement{a}
ward_promise_extract(p) = let
  val vp = $extfcall(ptr, "ward_slot_get", p, 1)
  val () = $extfcall(void, "free", p)
in $UNSAFE.castvwtp0{a}(vp) end (* [U1] *)

implement{a}{s}
ward_promise_discard(p) = $extfcall(void, "free", p)

implement{a}{b}
ward_promise_then(p, f) = let
  val chain = _ward_malloc_bytes(16)
  val () = $extfcall(void, "memset", chain, 0, 16)
  val () = $extfcall(void, "ward_slot_set", p, 2,
                     $UNSAFE.castvwtp0{ptr}(f)) (* [U1] *)
  val () = $extfcall(void, "ward_slot_set", p, 3, chain)
in chain end

end (* local *)
