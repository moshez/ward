(* ANTI-EXERCISER: write while frozen *)
(* This MUST fail to compile — can't use ward_own after freezing *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val own = ward_malloc (16)
  val @(frozen, borrow) = ward_freeze (own)
  (* own is consumed by freeze — can't memset through it *)
  val () = ward_memset (own, 0, 16)
  val () = ward_drop (frozen, borrow)
  val own2 = ward_thaw (frozen)
  val () = ward_free (own2)
in end
