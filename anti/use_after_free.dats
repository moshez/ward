(* ANTI-EXERCISER: use after free *)
(* This MUST fail to compile — sized_free consumes the linear value *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val raw = sized_malloc (16)
  val () = sized_free (raw)
  (* raw is consumed — using it again is a type error *)
  val p = raw_ptr (raw)
in end
