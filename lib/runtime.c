/* runtime.c -- Freestanding WASM runtime: bump allocator + memory ops */

/* Heap: grows upward from __heap_base (set by linker) */
extern unsigned char __heap_base;
static unsigned char *heap_ptr = &__heap_base;

void *malloc(int size) {
    /* Align to 8 bytes */
    unsigned long addr = (unsigned long)heap_ptr;
    addr = (addr + 7u) & ~7u;
    void *result = (void *)addr;
    heap_ptr = (unsigned char *)(addr + size);
    return result;
}

void free(void *ptr) {
    /* Bump allocator: free is a no-op */
    (void)ptr;
}

void *memset(void *s, int c, unsigned int n) {
    unsigned char *p = (unsigned char *)s;
    unsigned char byte = (unsigned char)c;
    while (n--) *p++ = byte;
    return s;
}

void *memcpy(void *dst, const void *src, unsigned int n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) *d++ = *s++;
    return dst;
}

/* DOM state global — single-instance for ward_dom_checkout/ward_dom_redeem */
static void *_ward_dom_stored = 0;
void ward_dom_global_set(void *p) { _ward_dom_stored = p; }
void *ward_dom_global_get(void) { return _ward_dom_stored; }

/* IDB result stash — JS stores malloc'd ptr here, ATS2 recovers via ward_idb_get_result */
static void *_ward_idb_stash_ptr = 0;
static int _ward_idb_stash_len = 0;
void ward_idb_stash_set(void *p, int len) {
    _ward_idb_stash_ptr = p; _ward_idb_stash_len = len;
}
void *ward_idb_stash_get_ptr(void) { return _ward_idb_stash_ptr; }

/* Bridge stash — shared by fetch, file, decompress, notify, listener */
static void *_ward_bridge_stash_ptr = 0;
static int _ward_bridge_stash_int[4] = {0};
void ward_bridge_stash_set_ptr(void *p) { _ward_bridge_stash_ptr = p; }
void *ward_bridge_stash_get_ptr(void) { return _ward_bridge_stash_ptr; }
void ward_bridge_stash_set_int(int slot, int v) { _ward_bridge_stash_int[slot] = v; }
int ward_bridge_stash_get_int(int slot) { return _ward_bridge_stash_int[slot]; }

/* Measure stash — 6 slots for x, y, w, h, top, left */
static int _ward_measure[6] = {0};
void ward_measure_set(int slot, int v) { _ward_measure[slot] = v; }
int ward_measure_get(int slot) { return _ward_measure[slot]; }

/* Listener table — max 64 listeners */
#define WARD_MAX_LISTENERS 64
static void *_ward_listener_table[WARD_MAX_LISTENERS] = {0};
void ward_listener_set(int id, void *cb) {
    if (id >= 0 && id < WARD_MAX_LISTENERS) _ward_listener_table[id] = cb;
}
void *ward_listener_get(int id) {
    if (id >= 0 && id < WARD_MAX_LISTENERS) return _ward_listener_table[id];
    return (void*)0;
}
