(* ANTI-EXERCISER: double free *)
(* This MUST fail to compile — can't free the same linear value twice *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val own = ward_malloc (16)
  val () = ward_free (own)
  val () = ward_free (own)
in end
