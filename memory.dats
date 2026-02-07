(* memory.dats -- Ward: linear memory safety implementations *)
(* The "unsafe core" that the type system protects users from touching. *)
(* At runtime all proofs are erased — zero overhead. *)

#include "share/atspre_staload.hats"
staload "./memory.sats"

local

  assume ward_arr(a, l, n) = ptr l
  assume ward_arr_frozen(a, l, n, k) = ptr l
  assume ward_arr_borrow(a, l, n) = ptr l
  assume ward_safe_text(n) = ptr
  assume ward_text_builder(n, i) = ptr

in

extern fun _ward_malloc_bytes (n: int): [l:agz] ptr l = "mac#malloc"

implement{a}
ward_arr_alloc{n}(n) = let
  val nbytes = n * sz2i(sizeof<a>)
  val p = _ward_malloc_bytes(nbytes)
  val () = $extfcall(void, "memset", p, 0, nbytes)
in
  p
end

implement{a}
ward_arr_free{l}{n}(arr) =
  $extfcall(void, "free", arr)

implement{a}
ward_arr_get{l}{n,i}(arr, i) =
  $UNSAFE.ptr0_get<a>(ptr_add<a>(arr, i))

implement{a}
ward_arr_set{l}{n,i}(arr, i, v) =
  $UNSAFE.ptr0_set<a>(ptr_add<a>(arr, i), v)

implement{a}
ward_arr_split{l}{n,m}(arr, m) = let
  val tail = $UNSAFE.cast{ptr(l+m)}(ptr_add<a>(arr, m))
in
  @(arr, tail)
end

implement{a}
ward_arr_join{l}{n,m}(left, right) = left

implement{a}
ward_arr_freeze{l}{n}(arr) = @(arr, arr)

implement{a}
ward_arr_thaw{l}{n}(frozen) = frozen

implement{a}
ward_arr_dup{l}{n}{k}(frozen, borrow) = borrow

implement{a}
ward_arr_drop{l}{n}{k}(frozen, borrow) = ()

implement{a}
ward_arr_read{l}{n,i}(borrow, i) =
  $UNSAFE.ptr0_get<a>(ptr_add<a>(borrow, i))

implement{a}
ward_arr_borrow_split{l}{n,m}{k}(frozen, borrow, m) = let
  val tail = $UNSAFE.cast{ptr(l+m)}(ptr_add<a>(borrow, m))
in
  @(borrow, tail)
end

implement{a}
ward_arr_borrow_join{l}{n,m}{k}(frozen, left, right) = left

implement
ward_text_build{n}(n) = _ward_malloc_bytes(n)

implement
ward_text_putc{c}{n}{i}(b, i, c) = let
  val () = $UNSAFE.ptr0_set<byte>(ptr_add<byte>(b, i), $UNSAFE.cast{byte}(c))
in b end

implement
ward_text_done{n}(b) = b

implement
ward_safe_text_get{n,i}(t, i) =
  $UNSAFE.ptr0_get<byte>(ptr_add<byte>(t, i))

end (* local *)
