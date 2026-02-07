(* ANTI-EXERCISER: thaw with outstanding borrows *)
(* This MUST fail to compile — can't thaw when borrow count > 0 *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val raw = sized_malloc (16)
  val @(frozen, borrow) = raw_freeze (raw)
  (* thaw requires borrow count == 0, but we still have borrow *)
  val raw2 = raw_thaw (frozen)
  val () = sized_free (raw2)
in end
