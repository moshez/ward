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
  val raw = sized_malloc (40)
  val rp = raw_ptr (raw)

  (* Split into 16 + 24 *)
  val @(head, tail) = raw_advance (raw, 16)

  (* Memset the head to 0xAA *)
  val hp = raw_ptr (head)
  val () = safe_memset (head, hp, 170, 16)

  (* Rejoin and free *)
  val whole = raw_rejoin (head, tail)
  val () = sized_free (whole)
in
  1 (* success *)
end

(* === Export: exercise layers 4 (borrow protocol) === *)
extern fun ward_test_borrow (): int = "mac#"
implement ward_test_borrow () = let
  val raw = sized_malloc (16)
  val rp = raw_ptr (raw)
  val () = safe_memset (raw, rp, 42, 1)

  (* Freeze *)
  val @(frozen, borrow1) = raw_freeze (raw)
  val bp = raw_borrow_ptr (borrow1)
  val v = raw_borrow_read (borrow1, bp, 0)

  (* Clone + return both *)
  val borrow2 = raw_borrow_clone (frozen, borrow1)
  val () = raw_borrow_return (frozen, borrow1)
  val () = raw_borrow_return (frozen, borrow2)

  (* Thaw + free *)
  val raw = raw_thaw (frozen)
  val () = sized_free (raw)
in
  v (* return the byte we read *)
end

(* === Export: exercise layers 5-6 (typed arrays + borrows) === *)
extern fun ward_test_typed (): int = "mac#"
implement ward_test_typed () = let
  val raw = sized_malloc (40)
  val rp = raw_ptr (raw)
  val tp = tptr_init<int> (raw, rp, 10)
  val tpp = tptr_ptr<int> (tp)

  (* Write and read *)
  val () = tptr_set<int> (tp, tpp, 5, 42)
  val v1 = tptr_get<int> (tp, tpp, 5)

  (* Freeze and read through borrow *)
  val @(frozen, borrow1) = tptr_freeze<int> (tp)
  val bp = tptr_borrow_getptr<int> (borrow1)
  val v2 = tptr_borrow_get<int> (borrow1, bp, 5)

  (* Return borrow, thaw, write *)
  val () = tptr_borrow_return<int> (frozen, borrow1)
  val tp2 = tptr_thaw<int> (frozen)
  val tpp2 = tptr_ptr<int> (tp2)
  val () = tptr_set<int> (tp2, tpp2, 5, 99)
  val v3 = tptr_get<int> (tp2, tpp2, 5)

  (* Cleanup *)
  val raw_back = tptr_dissolve<int> (tp2)
  val () = sized_free (raw_back)
in
  v1 + v2 + v3 (* 42 + 42 + 99 = 183 *)
end
