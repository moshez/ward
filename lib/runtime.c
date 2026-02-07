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
