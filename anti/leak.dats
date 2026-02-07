(* ANTI-EXERCISER: memory leak *)
(* This MUST fail to compile — linear value not consumed *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val raw = sized_malloc (16)
  (* raw is never freed — linear type error *)
in end
