/* ward_prelude.h -- C-level primitives for ward (native build) */
#ifndef WARD_PRELUDE_H
#define WARD_PRELUDE_H

#include <string.h>

/* All ward viewtypes are pointers at runtime */
#define ward_own(...) atstype_ptrk
#define ward_frozen(...) atstype_ptrk
#define ward_borrow(...) atstype_ptrk
#define ward_arr(...) atstype_ptrk
#define ward_arr_frozen(...) atstype_ptrk
#define ward_arr_borrow(...) atstype_ptrk

/* Byte-level pointer arithmetic (no sizeof scaling) */
#define ward_ptr_add(p, n) ((void*)((char*)(p) + (n)))

#endif /* WARD_PRELUDE_H */
