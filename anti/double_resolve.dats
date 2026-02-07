(* ANTI-EXERCISER: double resolve *)
(* This MUST fail to compile — resolver consumed by first resolve *)

#include "share/atspre_staload.hats"
staload "./../memory.sats"
staload "./../promise.sats"
staload _ = "./../memory.dats"
staload _ = "./../promise.dats"

fun bad (): void = let
  val @(p, r) = ward_promise_create<int> ()
  val () = ward_promise_resolve<int> (r, 1)
  val () = ward_promise_resolve<int> (r, 2)  (* r already consumed — type error *)
  val () = ward_promise_discard<int><Pending> (p)
in end
