/* runtime.h -- Freestanding WASM runtime for ward */
/* Replaces ATS2 pats_ccomp_{basics,typedefs,instrset}.h for --target=wasm32 */
#ifndef WARD_RUNTIME_H
#define WARD_RUNTIME_H

/* === Type definitions (pats_ccomp_typedefs.h) === */

typedef void atstype_void;
typedef void atsvoid_t0ype;

typedef int atstype_int;
typedef unsigned int atstype_uint;
typedef long int atstype_lint;
typedef unsigned long int atstype_ulint;
typedef long long int atstype_llint;
typedef unsigned long long int atstype_ullint;
typedef short int atstype_sint;
typedef unsigned short int atstype_usint;

typedef atstype_lint atstype_ssize;
typedef atstype_ulint atstype_size;

typedef int atstype_bool;
typedef unsigned char atstype_byte;
typedef char atstype_char;
typedef signed char atstype_schar;
typedef unsigned char atstype_uchar;
typedef char *atstype_string;
typedef char *atstype_stropt;
typedef char *atstype_strptr;
typedef void *atstype_ptr;
typedef void *atstype_ptrk;
typedef void *atstype_ref;
typedef void *atstype_boxed;
typedef void *atstype_datconptr;
typedef void *atstype_datcontyp;
typedef void *atstype_arrptr;
typedef void *atstype_funptr;
typedef void *atstype_cloptr;

#define atstkind_type(tk) tk
#define atstkind_t0ype(tk) tk

#ifndef _ATSTYPE_VAR_SIZE_
#define _ATSTYPE_VAR_SIZE_ 0X10000
#endif
typedef struct { char _[_ATSTYPE_VAR_SIZE_]; } atstype_var[0];

#define atstyvar_type(a) atstype_var
#define atstybox_type(hit) atstype_boxed
#define atsrefarg0_type(hit) hit
#define atsrefarg1_type(hit) atstype_ref

/* === Basics (pats_ccomp_basics.h) === */

#define atsbool_true 1
#define atsbool_false 0
#define atsptr_null ((void*)0)
#define the_atsptr_null ((void*)0)

#define ATSstruct struct

#define ATSextern() extern
#define ATSstatic() static
#define ATSinline() static inline

#define ATSdynload()
#define ATSdynloadflag_sta(flag)
#define ATSdynloadflag_ext(flag) extern int flag
#define ATSdynloadflag_init(flag) int flag = 0
#define ATSdynloadflag_minit(flag) int flag = 0
#define ATSdynloadset(flag) flag = 1
#define ATSdynloadfcall(dynloadfun) dynloadfun()

#define ATSassume(flag) void *flag = (void*)0

#define ATSdyncst_mac(d2c)
#define ATSdyncst_castfn(d2c)
#define ATSdyncst_extfun(d2c, targs, tres) extern tres d2c targs
#define ATSdyncst_stafun(d2c, targs, tres) static tres d2c targs
#define ATSdyncst_valimp(d2c, type) type d2c
#define ATSdyncst_valdec(d2c, type) extern type d2c

/* === Instruction set (pats_ccomp_instrset.h) === */

#define ATSif(x) if(x)
#define ATSthen()
#define ATSelse() else
#define ATSifthen(x) if(x)
#define ATSifnthen(x) if(!(x))

#define ATSreturn(x) return(x)
#define ATSreturn_void(x) return

#define ATSfunbody_beg()
#define ATSfunbody_end()

#define ATSPMVint(i) i
#define ATSPMVintrep(rep) (rep)
#define ATSPMVbool_true() atsbool_true
#define ATSPMVbool_false() atsbool_false
#define ATSPMVchar(c) (c)
#define ATSPMVstring(str) (str)
#define ATSPMVi0nt(tok) (tok)
#define ATSPMVempty() /*empty*/
#define ATSPMVextval(name) (name)
#define ATSPMVptrof(lval) (&(lval))
#define ATSPMVptrof_void(lval) ((void*)0)
#define ATSPMVrefarg0(val) (val)
#define ATSPMVrefarg1(ref) (ref)
#define ATSPMVsizeof(hit) (sizeof(hit))
#define ATSPMVfunlab(flab) (flab)
#define ATSPMVcastfn(d2c, hit, arg) ((hit)arg)
#define ATSPMVtyrep(rep) (rep)

#define ATSfuncall(fun, funarg) (fun)funarg
#define ATSextfcall(fun, funarg) (fun)funarg
#define ATSextmcall(obj, mtd, funarg) (obj->mtd)funarg

#define ATStmpdec(tmp, hit) hit tmp
#define ATStmpdec_void(tmp)
#define ATSstatmpdec(tmp, hit) static hit tmp
#define ATSstatmpdec_void(tmp)

#define ATSderef(pmv, hit) (*(hit*)pmv)

#define ATSCKnot(x) ((x)==0)
#define ATSCKiseqz(x) ((x)==0)
#define ATSCKisneqz(x) ((x)!=0)
#define ATSCKptriscons(x) (0 != (void*)(x))
#define ATSCKptrisnull(x) (0 == (void*)(x))

#define ATSINSlab(lab) lab
#define ATSINSgoto(lab) goto lab
#define ATSINSflab(flab) flab
#define ATSINSfgoto(flab) goto flab

#define ATSINSmove(tmp, val) (tmp = val)
#define ATSINSpmove(tmp, hit, val) (*(hit*)tmp = val)
#define ATSINSmove_void(tmp, command) command
#define ATSINSpmove_void(tmp, hit, command) command
#define ATSINSmove_nil(tmp) (tmp = ((void*)0))

#define ATSSELfltrec(pmv, tyrec, lab) ((pmv).lab)

#define ATSINSmove_fltrec_beg()
#define ATSINSmove_fltrec_end()
#define ATSINSstore_fltrec_ofs(tmp, tyrec, lab, val) ((tmp).lab = val)

#define ATSINSload(tmp, pmv) (tmp = pmv)
#define ATSINSstore(pmv1, pmv2) (pmv1 = pmv2)
#define ATSINSxstore(tmp, pmv1, pmv2) (tmp = pmv1, pmv1 = pmv2, pmv2 = tmp)

#define ATStailcal_beg() do {
#define ATStailcal_end() } while(0) ;
#define ATSINSmove_tlcal(apy, tmp) (apy = tmp)
#define ATSINSargmove_tlcal(arg, apy) (arg = apy)

#define ATSbranch_beg()
#define ATSbranch_end() break ;
#define ATScaseof_beg() do {
#define ATScaseof_end() } while(0) ;

#define ATSextcode_beg()
#define ATSextcode_end()

/* === Prelude function macros (used by template instantiations) === */

#define atspre_g1uint2int_size_int(x) ((int)(x))
#define atspre_g0int_add_int(x, y) ((x) + (y))
#define atspre_g1int_mul_int(x, y) ((x) * (y))
#define atspre_g0int2uint_int_size(x) ((atstype_size)(x))
#define atspre_g0uint_mul_size(x, y) ((x) * (y))
#define atspre_add_ptr0_bsz(p, n) ((void*)((char*)(p) + (n)))
#define atspre_g1int2int_int_int(x) (x)
#define atspre_g1int_lt_int(x, y) ((x) < (y))
#define atspre_g1int_add_int(x, y) ((x) + (y))
#define atspre_char2int1(c) ((int)(c))

/* === Ward-specific === */

/* Ward viewtypes are all pointers at runtime */
#define ward_arr(...) atstype_ptrk
#define ward_arr_frozen(...) atstype_ptrk
#define ward_arr_borrow(...) atstype_ptrk
#define ward_safe_text(...) atstype_ptrk
#define ward_text_builder(...) atstype_ptrk

/* Memory operations (implemented in runtime.c) */
void *malloc(int size);
void free(void *ptr);
void *memset(void *s, int c, unsigned int n);
void *memcpy(void *dst, const void *src, unsigned int n);

/* DOM helpers */
#define ward_dom_state(...) atstype_ptrk
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

#endif /* WARD_RUNTIME_H */
