(* ANTI-EXERCISER: extract from pending *)
(* This MUST fail to compile — extract requires Resolved, not Pending *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"
staload "./../promise.sats"
staload _ = "./../memory.dats"
staload _ = "./../promise.dats"

fun bad (): int = let
  val @(p, r) = ward_promise_create<int> ()
  val v = ward_promise_extract<int> (p)  (* p is Pending, not Resolved *)
  val () = ward_promise_resolve<int> (r, 0)
in v end
