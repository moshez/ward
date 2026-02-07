(* ANTI-EXERCISER: buffer overflow *)
(* This MUST fail to compile — memset size exceeds buffer capacity *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"

fun bad (): void = let
  val raw = sized_malloc (16)
  val p = raw_ptr (raw)
  (* 32 > 16 — constraint n <= cap is violated *)
  val () = safe_memset (raw, p, 0, 32)
  val () = sized_free (raw)
in end
