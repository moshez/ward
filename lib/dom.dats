(* dom.dats — Ward DOM implementation with streaming *)
(* Trusted core: writes diff protocol bytes to owned buffer, flushes to bridge.
   Stream API batches multiple ops into 256KB buffer, auto-flushes when full.
   No globals for cursor — stream is a ward_arr<ptr>(2): [buf, cursor]. *)

#include "share/atspre_staload.hats"
staload "./memory.sats"
staload "./dom.sats"
staload _ = "./memory.dats"

(* Bridge flush — host-provided *)
extern fun _ward_dom_flush
  (buf: ptr, len: int): void = "mac#ward_dom_flush"

(* Allocator *)
extern fun _ward_malloc_bytes
  (n: int): [l:agz] ptr l = "mac#malloc"

local

assume ward_dom_state(l) = ptr l
assume ward_dom_stream(l) = ward_arr(ptr, l, 2)   (* [buf, cursor] *)
assume ward_dom_ticket = ptr         (* zero-cost dummy *)

in

(*
 * $UNSAFE justifications — each use is marked with its pattern tag.
 *
 * [U1] cast{ptr}(tag) for ward_safe_text -> ptr (create_element, set_attr):
 *   ward_safe_text is abstype assumed as ptr in memory.dats, but that
 *   assumption is invisible from this module (cross-module abstraction).
 *   Alternative considered: expose ward_safe_text_ptr in memory.sats.
 *   Rejected: would let user code obtain raw pointers, breaking encapsulation.
 *
 * [U2] castvwtp1{ptr}(text/value) for ward_arr_borrow -> ptr
 *   (set_text, set_attr, set_style):
 *   Same cross-module barrier. castvwtp1 (not castvwtp0) preserves the
 *   borrow — the value is !-qualified and not consumed.
 *   Alternative considered: expose ward_arr_borrow_ptr in memory.sats.
 *   Rejected: same reason — would expose raw pointers to user code.
 *
 * [U3] ward_dom_checkout / ward_dom_redeem:
 *   Erases/recovers ward_dom_state to/from ptr via global storage.
 *   Justified: cross-module async boundary requires global stash.
 *   Alternative considered: pass state through promise chain.
 *   Rejected: promise chain carries t@ype values, not viewtypes.
 *
 * [U5] cast{int}(ward_arr_get<ptr>(stream,1)) / cast{ptr}(cursor):
 *   The cursor integer (0..262144) is stored in a pointer-sized slot.
 *   On wasm32 (4-byte ptr) and native (8-byte ptr), the round-trip is
 *   safe because the value fits in both types.
 *   Alternative considered: dedicated int field.
 *   Rejected: ward_arr<ptr> provides uniform 2-slot storage.
 *)

(* --- Lifecycle --- *)

implement
ward_dom_init() = _ward_malloc_bytes(4)  (* lightweight token *)

implement
ward_dom_fini{l}(state) = $extfcall(void, "free", state)

(* --- Async boundary --- *)

implement
ward_dom_checkout{l}(state) = let
  val () = $extfcall(void, "ward_dom_global_set", state)
in $UNSAFE.cast{ward_dom_ticket}(0) end (* [U3] *)

implement
ward_dom_redeem(ticket) = let
  val _ = ticket
  val p = $extfcall(ptr, "ward_dom_global_get")
in $UNSAFE.cast{[l:agz] ptr l}(p) end (* [U3] *)

(* --- Stream helpers --- *)

fn _ward_stream_buf{l:agz}(stream: !ward_dom_stream(l)): ptr =
  ward_arr_get<ptr>(stream, 0)

fn _ward_stream_cursor{l:agz}(stream: !ward_dom_stream(l)): int =
  $UNSAFE.cast{int}(ward_arr_get<ptr>(stream, 1)) (* [U5] *)

fn _ward_stream_set_cursor{l:agz}(stream: !ward_dom_stream(l), c: int): void =
  ward_arr_set<ptr>(stream, 1, $UNSAFE.cast{ptr}(c)) (* [U5] *)

fn _ward_stream_auto_flush{l:agz}(stream: !ward_dom_stream(l), needed: int): int = let
  val buf = _ward_stream_buf(stream)
  val c = _ward_stream_cursor(stream)
in
  if c + needed > WARD_DOM_BUF_CAP_DYN then let
    val () = _ward_dom_flush(buf, c)
    val () = _ward_stream_set_cursor(stream, 0)
  in 0 end
  else c
end

(* --- Stream lifecycle --- *)

implement
ward_dom_stream_begin{l}(state) = let
  val () = $extfcall(void, "free", state)  (* free state token *)
  val buf = _ward_malloc_bytes(WARD_DOM_BUF_CAP_DYN)
  val stream = ward_arr_alloc<ptr>(2)
  val () = ward_arr_set<ptr>(stream, 0, buf)
  val () = ward_arr_set<ptr>(stream, 1, $UNSAFE.cast{ptr}(0)) (* [U5] *)
in stream end

implement
ward_dom_stream_end{l}(stream) = let
  val buf = ward_arr_get<ptr>(stream, 0)
  val c = $UNSAFE.cast{int}(ward_arr_get<ptr>(stream, 1)) (* [U5] *)
  val () = if c > 0 then _ward_dom_flush(buf, c)
  val () = $extfcall(void, "free", buf)
  val () = ward_arr_free<ptr>(stream)
in _ward_malloc_bytes(4) end (* new state token *)

(*
 * Diff protocol (little-endian):
 *   CREATE_ELEMENT: [1:op=4] [4:node_id] [4:parent_id] [1:tag_len] [tag_data]
 *   SET_TEXT:       [1:op=1] [4:node_id] [1:lo] [1:hi]  [text_data]
 *   SET_ATTR:       [1:op=2] [4:node_id] [1:name_len]   [name_data]
 *                                        [1:lo] [1:hi]  [value_data]
 *   REMOVE_CHILDREN:[1:op=3] [4:node_id]
 *)

(* --- Stream ops --- *)

implement
ward_dom_stream_create_element{l}{tl}
  (stream, node_id, parent_id, tag, tag_len) = let
  val tl: int = tag_len
  val op_size = 10 + tl
  val c = _ward_stream_auto_flush(stream, op_size)
  val buf = _ward_stream_buf(stream)
  val () = $extfcall(void, "ward_set_byte", buf, c, 4)
  val () = $extfcall(void, "ward_set_i32", buf, c + 1, node_id)
  val () = $extfcall(void, "ward_set_i32", buf, c + 5, parent_id)
  val () = $extfcall(void, "ward_set_byte", buf, c + 9, tl)
  val () = $extfcall(void, "ward_copy_at", buf, c + 10,
                     $UNSAFE.cast{ptr}(tag), tl) (* [U1] *)
  val () = _ward_stream_set_cursor(stream, c + op_size)
in stream end

implement
ward_dom_stream_set_text{l}{lb}{tl}
  (stream, node_id, text, text_len) = let
  val tl: int = text_len
  val op_size = 7 + tl
  val c = _ward_stream_auto_flush(stream, op_size)
  val buf = _ward_stream_buf(stream)
  val () = $extfcall(void, "ward_set_byte", buf, c, 1)
  val () = $extfcall(void, "ward_set_i32", buf, c + 1, node_id)
  val () = $extfcall(void, "ward_set_byte", buf, c + 5, tl)
  val () = $extfcall(void, "ward_set_byte", buf, c + 6, 0)
  val () = $extfcall(void, "ward_copy_at", buf, c + 7,
                     $UNSAFE.castvwtp1{ptr}(text), tl) (* [U2] *)
  val () = _ward_stream_set_cursor(stream, c + op_size)
in stream end

implement
ward_dom_stream_set_attr{l}{lb}{nl}{vl}
  (stream, node_id, attr_name, name_len, value, value_len) = let
  val nl: int = name_len
  val vl: int = value_len
  val op_size = 6 + nl + 2 + vl
  val c = _ward_stream_auto_flush(stream, op_size)
  val buf = _ward_stream_buf(stream)
  val () = $extfcall(void, "ward_set_byte", buf, c, 2)
  val () = $extfcall(void, "ward_set_i32", buf, c + 1, node_id)
  val () = $extfcall(void, "ward_set_byte", buf, c + 5, nl)
  val () = $extfcall(void, "ward_copy_at", buf, c + 6,
                     $UNSAFE.cast{ptr}(attr_name), nl) (* [U1] *)
  val off = c + 6 + nl
  val () = $extfcall(void, "ward_set_byte", buf, off, vl)
  val () = $extfcall(void, "ward_set_byte", buf, off + 1, 0)
  val () = $extfcall(void, "ward_copy_at", buf, off + 2,
                     $UNSAFE.castvwtp1{ptr}(value), vl) (* [U2] *)
  val () = _ward_stream_set_cursor(stream, c + op_size)
in stream end

implement
ward_dom_stream_set_style{l}{lb}{vl}
  (stream, node_id, value, value_len) = let
  val vl: int = value_len
  val op_size = 13 + vl
  val c = _ward_stream_auto_flush(stream, op_size)
  val buf = _ward_stream_buf(stream)
  (* Hardcoded "style" = 115 116 121 108 101 *)
  val () = $extfcall(void, "ward_set_byte", buf, c, 2)
  val () = $extfcall(void, "ward_set_i32", buf, c + 1, node_id)
  val () = $extfcall(void, "ward_set_byte", buf, c + 5, 5)
  val () = $extfcall(void, "ward_set_byte", buf, c + 6, 115)
  val () = $extfcall(void, "ward_set_byte", buf, c + 7, 116)
  val () = $extfcall(void, "ward_set_byte", buf, c + 8, 121)
  val () = $extfcall(void, "ward_set_byte", buf, c + 9, 108)
  val () = $extfcall(void, "ward_set_byte", buf, c + 10, 101)
  val () = $extfcall(void, "ward_set_byte", buf, c + 11, vl)
  val () = $extfcall(void, "ward_set_byte", buf, c + 12, 0)
  val () = $extfcall(void, "ward_copy_at", buf, c + 13,
                     $UNSAFE.castvwtp1{ptr}(value), vl) (* [U2] *)
  val () = _ward_stream_set_cursor(stream, c + op_size)
in stream end

implement
ward_dom_stream_remove_children{l}(stream, node_id) = let
  val op_size = 5
  val c = _ward_stream_auto_flush(stream, op_size)
  val buf = _ward_stream_buf(stream)
  val () = $extfcall(void, "ward_set_byte", buf, c, 3)
  val () = $extfcall(void, "ward_set_i32", buf, c + 1, node_id)
  val () = _ward_stream_set_cursor(stream, c + op_size)
in stream end

(* --- Safe text stream variants --- *)

implement
ward_dom_stream_set_safe_text{l}{tl}
  (stream, node_id, text, text_len) = let
  val tl: int = text_len
  val op_size = 7 + tl
  val c = _ward_stream_auto_flush(stream, op_size)
  val buf = _ward_stream_buf(stream)
  val () = $extfcall(void, "ward_set_byte", buf, c, 1)
  val () = $extfcall(void, "ward_set_i32", buf, c + 1, node_id)
  val () = $extfcall(void, "ward_set_byte", buf, c + 5, tl)
  val () = $extfcall(void, "ward_set_byte", buf, c + 6, 0)
  val () = $extfcall(void, "ward_copy_at", buf, c + 7,
                     $UNSAFE.cast{ptr}(text), tl) (* [U1] *)
  val () = _ward_stream_set_cursor(stream, c + op_size)
in stream end

implement
ward_dom_stream_set_attr_safe{l}{nl}{vl}
  (stream, node_id, attr_name, name_len, value, value_len) = let
  val nl: int = name_len
  val vl: int = value_len
  val op_size = 6 + nl + 2 + vl
  val c = _ward_stream_auto_flush(stream, op_size)
  val buf = _ward_stream_buf(stream)
  val () = $extfcall(void, "ward_set_byte", buf, c, 2)
  val () = $extfcall(void, "ward_set_i32", buf, c + 1, node_id)
  val () = $extfcall(void, "ward_set_byte", buf, c + 5, nl)
  val () = $extfcall(void, "ward_copy_at", buf, c + 6,
                     $UNSAFE.cast{ptr}(attr_name), nl) (* [U1] *)
  val off = c + 6 + nl
  val () = $extfcall(void, "ward_set_byte", buf, off, vl)
  val () = $extfcall(void, "ward_set_byte", buf, off + 1, 0)
  val () = $extfcall(void, "ward_copy_at", buf, off + 2,
                     $UNSAFE.cast{ptr}(value), vl) (* [U1] *)
  val () = _ward_stream_set_cursor(stream, c + op_size)
in stream end

end (* local *)
