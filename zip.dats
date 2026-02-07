(* zip.dats -- ZIP local file header parsing in pure ATS2 *)

(* NO C %{ blocks. All C interop uses = "mac#" externs declared in zip.sats.
   This follows the conversion pattern from old_quire_claude.md:
   Step 1: C primitives as extern (buf_get_u8, buf_get_u16le, buf_get_u32le)
   Step 2: No global state in %{ blocks
   Step 3: ATS implementations using the primitives *)

#include "share/atspre_staload.hats"
staload "./better_rust.sats"
staload "./zip.sats"

(* ============================================================
   Signature check: 0x04034b50 = {0x50, 0x4b, 0x03, 0x04}
   ============================================================ *)

implement zip_check_signature{l}{n}(pf, p) = let
  val b0 = buf_get_u8(pf, p, 0)
  val b1 = buf_get_u8(pf, p, 1)
  val b2 = buf_get_u8(pf, p, 2)
  val b3 = buf_get_u8(pf, p, 3)
in
  if b0 = 0x50 then
    if b1 = 0x4b then
      if b2 = 0x03 then
        if b3 = 0x04 then ZIP_SIG_YES()
        else ZIP_SIG_NO()
      else ZIP_SIG_NO()
    else ZIP_SIG_NO()
  else ZIP_SIG_NO()
end

(* ============================================================
   Parse the fixed 30-byte header
   ============================================================ *)

implement zip_parse_local_header{l}{n}(pf, p) = let
  val version   = buf_get_u16le(pf, p, 4)
  val flags     = buf_get_u16le(pf, p, 6)
  val compress  = buf_get_u16le(pf, p, 8)
  val mod_time  = buf_get_u16le(pf, p, 10)
  val mod_date  = buf_get_u16le(pf, p, 12)
  val crc       = buf_get_u32le(pf, p, 14)
  val comp_sz   = buf_get_u32le(pf, p, 18)
  val uncomp_sz = buf_get_u32le(pf, p, 22)
  val fname_len = buf_get_u16le(pf, p, 26)
  val extra_len = buf_get_u16le(pf, p, 28)
in
  @{
    version_needed= version,
    flags= flags,
    compression= compress,
    mod_time= mod_time,
    mod_date= mod_date,
    crc32= crc,
    compressed_size= comp_sz,
    uncompressed_size= uncomp_sz,
    filename_len= fname_len,
    extra_len= extra_len
  }
end

(* ============================================================
   Total header size = 30 + filename_len + extra_len
   ============================================================ *)

implement zip_local_header_total_size(hdr) =
  30 + hdr.filename_len + hdr.extra_len
