(* ANTI-EXERCISER: array out of bounds *)
(* This MUST fail to compile — index >= array length *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"
staload _ = "./../memory.dats"

fun bad (): void = let
  val own = ward_malloc (40)
  val arr = ward_arr_init<int> (own, 10)
  (* index 10 with array of length 10 — i < n violated *)
  val v = ward_arr_get<int> (arr, 10)
  val own_back = ward_arr_fini<int> (arr)
  val () = ward_free (own_back)
in end
