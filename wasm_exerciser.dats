(* wasm_exerciser.dats -- WASM exerciser: exports functions that exercise ward *)
(* JS calls these exported functions and checks return values *)

#include "share/atspre_staload.hats"
staload "./memory.sats"
dynload "./memory.dats"
staload _ = "./memory.dats"

(* === Export: exercise layers 1-3 (alloc, split, memops) === *)
extern fun ward_test_raw (): int = "mac#"
implement ward_test_raw () = let
  (* Allocate 40 bytes *)
  val own = ward_malloc (40)

  (* Split into 16 + 24 *)
  val @(head, tail) = ward_split (own, 16)

  (* Memset the head to 0xAA *)
  val () = ward_memset (head, 170, 16)

  (* Rejoin and free *)
  val whole = ward_join (head, tail)
  val () = ward_free (whole)
in
  1 (* success *)
end

(* === Export: exercise layers 4 (borrow protocol) === *)
extern fun ward_test_borrow (): int = "mac#"
implement ward_test_borrow () = let
  val own = ward_malloc (16)
  val () = ward_memset (own, 42, 1)

  (* Freeze *)
  val @(frozen, borrow1) = ward_freeze (own)
  val v = ward_read (borrow1, 0)

  (* Dup + drop both *)
  val borrow2 = ward_dup (frozen, borrow1)
  val () = ward_drop (frozen, borrow1)
  val () = ward_drop (frozen, borrow2)

  (* Thaw + free *)
  val own = ward_thaw (frozen)
  val () = ward_free (own)
in
  v (* return the byte we read *)
end

(* === Export: exercise layers 5-6 (typed arrays + borrows) === *)
extern fun ward_test_typed (): int = "mac#"
implement ward_test_typed () = let
  val arr = ward_arr_alloc<int> (10)

  (* Write and read *)
  val () = ward_arr_set<int> (arr, 5, 42)
  val v1 = ward_arr_get<int> (arr, 5)

  (* Freeze and read through borrow *)
  val @(frozen, borrow1) = ward_arr_freeze<int> (arr)
  val v2 = ward_arr_read<int> (borrow1, 5)

  (* Drop borrow, thaw, write *)
  val () = ward_arr_drop<int> (frozen, borrow1)
  val arr2 = ward_arr_thaw<int> (frozen)
  val () = ward_arr_set<int> (arr2, 5, 99)
  val v3 = ward_arr_get<int> (arr2, 5)

  (* Cleanup *)
  val () = ward_arr_free<int> (arr2)
in
  v1 + v2 + v3 (* 42 + 42 + 99 = 183 *)
end
