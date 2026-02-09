(* xml.dats — Cursor-based XML/HTML reader implementation *)
(* Reads offsets from borrow buffer. Uses raw ptr access [U1] pattern. *)

#include "share/atspre_staload.hats"
staload "./memory.sats"
staload "./xml.sats"
staload _ = "./memory.dats"

(*
 * $UNSAFE justifications:
 * [U1] castvwtp1{ptr}(buf) + ptr0_get<byte> — borrows buffer as raw ptr for
 *   byte-level reads. Same pattern as memory.dats [U1]. Bounds are the caller's
 *   responsibility (binary format is produced by trusted JS bridge code).
 * [U-arr] castvwtp0{ward_arr(byte,l,n)}(p) — same as listener.dats [U-arr].
 *   Wraps stashed malloc'd ptr as ward_arr.
 *)

(* JS import *)
extern fun _ward_js_parse_html
  (html: ptr, len: int): int = "mac#ward_js_parse_html"

(* Bridge stash *)
extern fun _ward_bridge_stash_get_ptr
  (): ptr = "mac#ward_bridge_stash_get_ptr"

(* Read a byte from ptr at offset, return as int *)
fn _read_byte(p: ptr, off: int): int =
  $UNSAFE.cast{int}($UNSAFE.ptr0_get<byte>(ptr_add<byte>(p, off))) (* [U1] *)

implement
ward_xml_parse_html{lb}{n}(html, len) =
  _ward_js_parse_html($UNSAFE.castvwtp1{ptr}(html), len) (* [U1] *)

implement
ward_xml_get_result{n}(len) = let
  val p = _ward_bridge_stash_get_ptr()
in $UNSAFE.castvwtp0{[l:agz] ward_arr(byte, l, n)}(p) end (* [U-arr] *)

implement
ward_xml_opcode{l}{n}{p}(buf, pos) = let
  val bp = $UNSAFE.castvwtp1{ptr}(buf)  (* [U1] borrow *)
in _read_byte(bp, pos) end

implement
ward_xml_element_open{l}{n}{p}(buf, pos) = let
  val bp = $UNSAFE.castvwtp1{ptr}(buf)  (* [U1] borrow *)
  val p0 : int = g0ofg1(pos)
  (* pos points to opcode byte (0x01); skip it *)
  val tag_len = _read_byte(bp, p0 + 1)
  val tag_off = p0 + 2
  val after_tag = tag_off + tag_len
  val attr_count = _read_byte(bp, after_tag)
  val next_pos = after_tag + 1
in @(tag_off, tag_len, attr_count, next_pos) end

implement
ward_xml_read_attr{l}{n}{p}(buf, pos) = let
  val bp = $UNSAFE.castvwtp1{ptr}(buf)  (* [U1] borrow *)
  val p0 : int = g0ofg1(pos)
  val name_len = _read_byte(bp, p0)
  val name_off = p0 + 1
  val after_name = name_off + name_len
  val val_lo = _read_byte(bp, after_name)
  val val_hi = _read_byte(bp, after_name + 1)
  val val_len = val_lo + val_hi * 256
  val val_off = after_name + 2
  val next_pos = val_off + val_len
in @(name_off, name_len, val_off, val_len, next_pos) end

implement
ward_xml_read_text{l}{n}{p}(buf, pos) = let
  val bp = $UNSAFE.castvwtp1{ptr}(buf)  (* [U1] borrow *)
  val p0 : int = g0ofg1(pos)
  (* pos points to opcode byte (0x03); skip it *)
  val lo = _read_byte(bp, p0 + 1)
  val hi = _read_byte(bp, p0 + 2)
  val text_len = lo + hi * 256
  val text_off = p0 + 3
  val next_pos = text_off + text_len
in @(text_off, text_len, next_pos) end
