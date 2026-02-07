(* ANTI-EXERCISER: thaw with outstanding borrows *)
(* This MUST fail to compile — can't thaw when borrow count > 0 *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val own = ward_malloc (16)
  val @(frozen, borrow) = ward_freeze (own)
  (* thaw requires borrow count == 0, but we still have borrow *)
  val own2 = ward_thaw (frozen)
  val () = ward_free (own2)
in end
