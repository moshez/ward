(* ANTI-EXERCISER: array out of bounds *)
(* This MUST fail to compile — index >= array length *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"
staload _ = "./../memory.dats"

fun bad (): void = let
  val raw = sized_malloc (40)
  val rp = raw_ptr (raw)
  val tp = tptr_init<int> (raw, rp, 10)
  val tpp = tptr_ptr<int> (tp)
  (* index 10 with array of length 10 — i < n violated *)
  val v = tptr_get<int> (tp, tpp, 10)
  val raw_back = tptr_dissolve<int> (tp)
  val () = sized_free (raw_back)
in end
