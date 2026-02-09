(* callback.dats — General-purpose callback implementation *)
(* Follows exact pattern of listener.dats *)

#include "share/atspre_staload.hats"
staload "./memory.sats"
staload "./callback.sats"
staload _ = "./memory.dats"

(*
 * $UNSAFE justifications:
 * [U-cb] castvwtp0{ptr}(cb) — erase cloref1 to ptr for table storage.
 *   Same pattern as listener.dats [U-cb]. Closure is heap-allocated cloref1,
 *   survives across multiple fires. Recovered in ward_on_callback.
 *)

(* Listener table — implemented in runtime.c *)
extern fun _ward_listener_set
  (id: int, cb: ptr): void = "mac#ward_listener_set"

extern fun _ward_listener_get
  (id: int): ptr = "mac#ward_listener_get"

implement
ward_callback_register(id, cb) = let
  val cbp = $UNSAFE.castvwtp0{ptr}(cb) (* [U-cb] *)
in _ward_listener_set(id, cbp) end

implement
ward_callback_fire(id, payload) = let
  val cbp = _ward_listener_get(id)
in
  if $UNSAFE.cast{int}(cbp) > 0 then let
    val _ = $extfcall(ptr, "ward_cloref1_invoke", cbp,
                      $UNSAFE.cast{ptr}(payload))
  in () end
  else ()
end

implement
ward_callback_remove(id) =
  _ward_listener_set(id, the_null_ptr)

implement
ward_on_callback(id, payload) =
  ward_callback_fire(id, payload)
