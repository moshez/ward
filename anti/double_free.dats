(* ANTI-EXERCISER: double free *)
(* This MUST fail to compile — can't free the same linear value twice *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val raw = sized_malloc (16)
  val () = sized_free (raw)
  val () = sized_free (raw)
in end
