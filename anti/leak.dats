(* ANTI-EXERCISER: memory leak *)
(* This MUST fail to compile — linear value not consumed *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val own = ward_malloc (16)
  (* own is never freed — linear type error *)
in end
