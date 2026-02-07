(* ANTI-EXERCISER: buffer overflow *)
(* This MUST fail to compile — memset size exceeds buffer capacity *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val own = ward_malloc (16)
  (* 32 > 16 — constraint n <= cap is violated *)
  val () = ward_memset (own, 0, 32)
  val () = ward_free (own)
in end
