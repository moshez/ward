/* ward_prelude.h -- C-level primitives for ward (native build) */
#ifndef WARD_PRELUDE_H
#define WARD_PRELUDE_H

#include <stdlib.h>
#include <string.h>

/* Enable libc malloc/free for ATS2 datavtype constructors */
#define ATS_MEMALLOC_LIBC

/* All ward viewtypes are pointers at runtime */
#define ward_arr(...) atstype_ptrk
#define ward_arr_frozen(...) atstype_ptrk
#define ward_arr_borrow(...) atstype_ptrk
#define ward_safe_text(...) atstype_ptrk
#define ward_text_builder(...) atstype_ptrk

/* Promise types */
#define ward_promise(...) atstype_ptrk
#define ward_promise_resolver(...) atstype_ptrk

/* Pointer-sized slot access (for promise struct) */
static inline void *ward_slot_get(void *p, int i) {
  return ((void**)p)[i];
}
static inline void ward_slot_set(void *p, int i, void *v) {
  ((void**)p)[i] = v;
}

/* Invoke a cloref1 closure: first word is function pointer */
static inline void *ward_cloref1_invoke(void *clo, void *arg) {
  typedef void *(*cfun)(void *clo, void *arg);
  cfun fp = *(cfun*)clo;
  return fp(clo, arg);
}

/* Promise chain resolution (monadic bind support).
   Iteratively resolves a promise and propagates through then-chains.
   When a callback returns a pending inner promise, wires forwarding. */
static inline void ward_promise_resolve_chain(void *p, void *v) {
  void **pp = (void **)p;
  while (1) {
    pp[0] = (void*)1;
    pp[1] = v;
    void *cb = pp[2];
    void *chain = pp[3];
    if (cb && chain) {
      void *inner = ward_cloref1_invoke(cb, v);
      void **ip = (void **)inner;
      if (ip[0]) {
        v = ip[1];
        pp = (void **)chain;
        continue;
      } else {
        ip[3] = chain;
        break;
      }
    } else if (chain) {
      pp = (void **)chain;
      continue;
    } else {
      break;
    }
  }
}

/* Allocate a zeroed promise struct (4 pointer-sized slots) */
static inline void *ward_promise_alloc(void) {
  int sz = 4 * sizeof(void*);
  void *p = malloc(sz);
  memset(p, 0, sz);
  return p;
}

/* Self-freeing closure wrapper for linear closures (cloptr1).
   When resolve_chain invokes this via ward_cloref1_invoke, the wrapper
   invokes the real cloptr1 then frees both it and the wrapper.
   Layout: [0]=wrapper_fn_ptr, [1]=real_cloptr1 */
static inline void *_ward_cloptr1_wrapper_invoke(void *wrapper, void *arg) {
  void **w = (void **)wrapper;
  void *real_clo = w[1];
  void *result = ward_cloref1_invoke(real_clo, arg);
  free(real_clo);
  free(wrapper);
  return result;
}

static inline void *_ward_cloptr1_wrap(void *f) {
  typedef void *(*cfun)(void *, void *);
  void **wrapper = (void **)malloc(2 * sizeof(void*));
  wrapper[0] = (void *)(cfun)_ward_cloptr1_wrapper_invoke;
  wrapper[1] = f;
  return (void *)wrapper;
}

/* Promise then_vt (monadic bind with linear closure).
   Wraps the cloptr1 in a self-freeing thunk so resolve_chain needs no
   special logic — it just sees a normal closure. */
static inline void *ward_promise_then_vt_impl(void *p, void *f) {
  void *chain = ward_promise_alloc();
  void **pp = (void **)p;
  if (pp[0]) {
    /* Already resolved — invoke and free immediately */
    void *inner = ward_cloref1_invoke(f, pp[1]);
    free(f);
    void **ip = (void **)inner;
    if (ip[0]) {
      ((void **)chain)[0] = (void*)1;
      ((void **)chain)[1] = ip[1];
    } else {
      ip[3] = chain;
    }
  } else {
    /* Pending — wrap in self-freeing thunk */
    pp[2] = _ward_cloptr1_wrap(f);
    pp[3] = chain;
  }
  return chain;
}

/* DOM helpers */
#define ward_dom_state(...) atstype_ptrk
#define ward_dom_stream(...) atstype_ptrk

static inline void ward_set_byte(void *p, int off, int v) {
  ((unsigned char*)p)[off] = (unsigned char)v;
}
static inline void ward_set_i32(void *p, int off, int v) {
  unsigned char *d = (unsigned char*)p + off;
  d[0] = v & 0xFF; d[1] = (v >> 8) & 0xFF;
  d[2] = (v >> 16) & 0xFF; d[3] = (v >> 24) & 0xFF;
}
static inline void ward_copy_at(void *dst, int off, const void *src, int n) {
  memcpy((char*)dst + off, src, n);
}
static inline void ward_dom_flush(void *buf, int len) {
  /* stub — in WASM, this calls the JS bridge */
}

/* IDB stash stubs (native build parity with runtime.c) */
static void *_ward_idb_stash_ptr = 0;
static int _ward_idb_stash_len = 0;
static inline void ward_idb_stash_set(void *p, int len) {
  _ward_idb_stash_ptr = p; _ward_idb_stash_len = len;
}
static inline void *ward_idb_stash_get_ptr(void) { return _ward_idb_stash_ptr; }

/* Bridge stash stubs (native build parity with runtime.c) */
static void *_ward_bridge_stash_ptr = 0;
static int _ward_bridge_stash_int[4] = {0};
static inline void ward_bridge_stash_set_ptr(void *p) { _ward_bridge_stash_ptr = p; }
static inline void *ward_bridge_stash_get_ptr(void) { return _ward_bridge_stash_ptr; }
static inline void ward_bridge_stash_set_int(int slot, int v) { _ward_bridge_stash_int[slot] = v; }
static inline int ward_bridge_stash_get_int(int slot) { return _ward_bridge_stash_int[slot]; }

/* Measure stash stubs */
static int _ward_measure[6] = {0};
static inline void ward_measure_set(int slot, int v) { _ward_measure[slot] = v; }
static inline int ward_measure_get(int slot) { return _ward_measure[slot]; }

/* Listener table stubs */
#define WARD_MAX_LISTENERS 64
static void *_ward_listener_table[WARD_MAX_LISTENERS] = {0};
static inline void ward_listener_set(int id, void *cb) {
  if (id >= 0 && id < WARD_MAX_LISTENERS) _ward_listener_table[id] = cb;
}
static inline void *ward_listener_get(int id) {
  if (id >= 0 && id < WARD_MAX_LISTENERS) return _ward_listener_table[id];
  return (void*)0;
}

#endif /* WARD_PRELUDE_H */
