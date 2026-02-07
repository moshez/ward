(* zip.sats -- Type declarations for ZIP local file header parsing *)

(* Uses dependent types and = "mac#" externs instead of C %{ blocks.
   All byte-level access goes through declared primitives. *)

#include "share/atspre_staload.hats"
staload "./better_rust.sats"

(* ============================================================
   Byte access primitives (declared here, implemented in C)
   ============================================================ *)

(* Read a single unsigned byte from a raw buffer at offset *)
fun buf_get_u8
  {l:agz}{n,off:nat | off < n}
  (pf: !raw_own(l, n), p: ptr l, off: int off)
  : [v:nat | v < 256] int v = "mac#"

(* Read a little-endian 16-bit unsigned integer *)
fun buf_get_u16le
  {l:agz}{n,off:nat | off + 1 < n}
  (pf: !raw_own(l, n), p: ptr l, off: int off)
  : [v:nat | v < 65536] int v = "mac#"

(* Read a little-endian 32-bit unsigned integer *)
fun buf_get_u32le
  {l:agz}{n,off:nat | off + 3 < n}
  (pf: !raw_own(l, n), p: ptr l, off: int off)
  : int = "mac#"

(* ============================================================
   ZIP local file header layout (§4.3.7 of APPNOTE.TXT)

   Offset  Size  Field
   0       4     signature (0x04034b50)
   4       2     version needed
   6       2     general purpose bit flag
   8       2     compression method
   10      2     last mod file time
   12      2     last mod file date
   14      4     crc-32
   18      4     compressed size
   22      4     uncompressed size
   26      2     file name length
   28      2     extra field length
   30      ...   file name
   30+n    ...   extra field
   ============================================================ *)

(* Proof that a buffer contains a valid ZIP local file header signature *)
dataprop ZIP_SIG_VALID(valid: bool) =
  | ZIP_SIG_YES(true)
  | ZIP_SIG_NO(false)

(* Minimum size of a local file header (fixed fields only) *)
stadef ZIP_LOCAL_HEADER_MIN = 30

(* Check if a buffer starts with the ZIP local file header signature *)
fun zip_check_signature
  {l:agz}{n:nat | n >= 4}
  (pf: !raw_own(l, n), p: ptr l)
  : [b:bool] ZIP_SIG_VALID(b)

(* Parsed ZIP local file header — all fields extracted *)
typedef zip_local_header = @{
  version_needed= int,
  flags= int,
  compression= int,
  mod_time= int,
  mod_date= int,
  crc32= int,
  compressed_size= int,
  uncompressed_size= int,
  filename_len= int,
  extra_len= int
}

(* Parse a local file header from a buffer that has a valid signature.
   Requires at least ZIP_LOCAL_HEADER_MIN bytes. *)
fun zip_parse_local_header
  {l:agz}{n:nat | n >= ZIP_LOCAL_HEADER_MIN}
  (pf: !raw_own(l, n), p: ptr l)
  : zip_local_header

(* Total size of the local file header including variable-length fields *)
fun zip_local_header_total_size
  (hdr: &zip_local_header)
  : int
