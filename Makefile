# Ward -- Linear memory safety library for ATS2
# Builds WASM output, native exerciser, and anti-exerciser checks

PATSHOME ?= $(HOME)/.ats2/ATS2-Postiats-int-0.4.2
PATSOPT  := PATSHOME=$(PATSHOME) $(PATSHOME)/bin/patsopt

CC       := gcc
CLANG    := clang
WASM_LD  := wasm-ld

CFLAGS_ATS := -I$(PATSHOME) -I$(PATSHOME)/ccomp/runtime
WARD_DIR   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# WASM flags
WASM_CFLAGS := --target=wasm32 -O2 -nostdlib -ffreestanding \
  -I$(WARD_DIR)exerciser/wasm_stubs -I$(PATSHOME) -I$(PATSHOME)/ccomp/runtime \
  -D_ATS_CCOMP_HEADER_NONE_ \
  -D_ATS_CCOMP_EXCEPTION_NONE_ \
  -D_ATS_CCOMP_PRELUDE_NONE_ \
  -include $(WARD_DIR)lib/runtime.h
WASM_LDFLAGS := --no-entry --export-dynamic \
  -z stack-size=65536 --initial-memory=1048576

# Anti-exerciser files (must all FAIL to compile)
ANTI_SRCS := $(wildcard exerciser/anti/*.dats)

# --- Default target ---
.PHONY: all clean exerciser wasm anti-exerciser check

all: wasm exerciser

check: wasm exerciser anti-exerciser

# --- ATS2 → C compilation ---
build:
	@mkdir -p build

build/memory_dats.c: lib/memory.dats lib/memory.sats | build
	$(PATSOPT) -o $@ -d $<

build/dom_dats.c: lib/dom.dats lib/dom.sats lib/memory.sats lib/memory.dats | build
	$(PATSOPT) -o $@ -d $<

build/promise_dats.c: lib/promise.dats lib/promise.sats lib/memory.sats lib/memory.dats | build
	$(PATSOPT) -o $@ -d $<

build/exerciser_dats.c: exerciser/exerciser.dats lib/memory.sats lib/memory.dats lib/dom.sats lib/dom.dats lib/promise.sats lib/promise.dats | build
	$(PATSOPT) -o $@ -d $<

build/wasm_exerciser_dats.c: exerciser/wasm_exerciser.dats lib/memory.sats lib/memory.dats | build
	$(PATSOPT) -o $@ -d $<

# --- Native exerciser (links with libc) ---
build/exerciser: build/memory_dats.c build/dom_dats.c build/promise_dats.c build/exerciser_dats.c lib/ward_prelude.h | build
	$(CC) $(CFLAGS_ATS) -include $(WARD_DIR)lib/ward_prelude.h \
	  -o $@ build/memory_dats.c build/dom_dats.c build/promise_dats.c build/exerciser_dats.c

exerciser: build/exerciser
	@echo "==> Running exerciser"
	@build/exerciser

# --- WASM build ---
build/memory_dats.o: build/memory_dats.c lib/runtime.h | build
	$(CLANG) $(WASM_CFLAGS) -c -o $@ $<

build/dom_dats.o: build/dom_dats.c lib/runtime.h | build
	$(CLANG) $(WASM_CFLAGS) -c -o $@ $<

build/promise_dats.o: build/promise_dats.c lib/runtime.h | build
	$(CLANG) $(WASM_CFLAGS) -c -o $@ $<

build/wasm_exerciser_dats.o: build/wasm_exerciser_dats.c lib/runtime.h | build
	$(CLANG) $(WASM_CFLAGS) -c -o $@ $<

build/runtime.o: lib/runtime.c lib/runtime.h | build
	$(CLANG) $(WASM_CFLAGS) -c -o $@ $<

build/ward.wasm: build/memory_dats.o build/dom_dats.o build/promise_dats.o build/wasm_exerciser_dats.o build/runtime.o
	$(WASM_LD) $(WASM_LDFLAGS) -o $@ $^

wasm: build/ward.wasm
	@echo "==> build/ward.wasm built"

# --- Anti-exerciser (verify unsafe code is rejected) ---
anti-exerciser:
	@echo "==> Anti-exerciser: verifying unsafe code is rejected"
	@pass=0; fail=0; \
	for f in $(ANTI_SRCS); do \
	  if $(PATSOPT) -o /dev/null -d $$f >/dev/null 2>&1; then \
	    echo "FAIL: $$f compiled (should have been rejected)"; \
	    fail=$$((fail + 1)); \
	  else \
	    echo "  ok: $$f rejected"; \
	    pass=$$((pass + 1)); \
	  fi; \
	done; \
	echo "==> $$pass rejected, $$fail unexpectedly compiled"; \
	test $$fail -eq 0

clean:
	rm -rf build
