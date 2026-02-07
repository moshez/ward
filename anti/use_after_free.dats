(* ANTI-EXERCISER: use after free *)
(* This MUST fail to compile — ward_free consumes the linear value *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val own = ward_malloc (16)
  val () = ward_free (own)
  (* own is consumed — using it again is a type error *)
  val () = ward_memset (own, 0, 1)
in end
