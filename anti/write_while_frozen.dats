(* ANTI-EXERCISER: write while frozen *)
(* This MUST fail to compile — can't use raw_own after freezing *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val raw = sized_malloc (16)
  val rp = raw_ptr (raw)
  val @(frozen, borrow) = raw_freeze (raw)
  (* raw is consumed by freeze — can't memset through it *)
  val () = safe_memset (raw, rp, 0, 16)
  val () = raw_borrow_return (frozen, borrow)
  val raw2 = raw_thaw (frozen)
  val () = sized_free (raw2)
in end
