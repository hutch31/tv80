# Makefile for TV80 verification test programs
#
# Builds Z80 assembly test programs into Verilog memory (.vmem) format
# that the cocotb testbench can array-write into ROM.
#
# Tools required:
#   sdcc       – Small Device C Compiler (for .c tests)
#   sdasz80    – SDCC Z80 assembler (for .asm / .ast tests)
#   ihex2mem.py – Intel HEX to Verilog memory converter (in ../../scripts/)
#
# Install on Debian/Ubuntu:
#   apt-get install sdcc
#
# Usage:
#   make          – build all new test programs
#   make all_func – also build functional tests from ../../tests/
#   make clean    – remove generated files

SCRIPTS_DIR := ../../scripts
TESTS_SRC   := ../../tests

# TESTS_SRC is kept for header includes only (e.g. tv80_env.h).
# All .c and .asm test sources live in this directory.
CC       := sdcc -mz80 -I$(TESTS_SRC) -I../../sc_env -I.
AS       := sdasz80
LD       := sdldz80
IHEX2MEM := $(SCRIPTS_DIR)/ihex2mem.py

# -----------------------------------------------------------------------
# New verification test programs (in verif/tests/)
# These use .area PROGMEM (ABS) with explicit .org so --no-std-crt0 is safe.
# -----------------------------------------------------------------------
VERIF_TESTS := \
    reset_test      \
    alu_arith       \
    alu_arith16     \
    alu_logic       \
    alu_rotate      \
    bit_ops         \
    load_reg        \
    load_mem        \
    jump_ops        \
    io_ops          \
    stack_ops       \
    exchange_ops    \
    misc_ops        \
    interrupt_im0   \
    interrupt_im1   \
    interrupt_im2   \
    nmi_ops         \
    busrq_test      \
	wait_test       \
	daa_carry       \
	bit_ix_iy       \
	load_sp_hl      \
	load_ix_iy_nn   \
	block_search    \
	ex_af_shadow    \
	daa_ops

VERIF_VMEM := $(addsuffix .vmem, $(VERIF_TESTS))

# -----------------------------------------------------------------------
# Functional tests – built from ../../tests/ source
# -----------------------------------------------------------------------
FUNC_TESTS_AST := alu_optest load_optest otir block_search_prog
FUNC_TESTS_ASM := basic_int
FUNC_TESTS_C   := hello fib

FUNC_VMEM := $(addsuffix .vmem, $(FUNC_TESTS_AST) $(FUNC_TESTS_ASM) $(FUNC_TESTS_C) bintr)

# -----------------------------------------------------------------------
# Pattern rules
# -----------------------------------------------------------------------

# .vmem from .ihx (both local and copied from TESTS_SRC)
%.vmem : %.ihx
	$(IHEX2MEM) $< $@

# Our new verif test programs (.asm → .rel → .ihx with no C runtime)
%.ihx : %.asm
	$(AS) -l -o $*.rel $<
	$(LD) -n -i -b _DATA=0x8000 $* $*.rel; test -f $*.ihx

# Functional .ast programs (sdcc z80 assembler convention).
# _CODE must be placed after the ABS INIT area (which ends ~0x00FF).
# Without an explicit base, sdldz80 defaults _CODE to 0x0000, overwriting INIT.
%.ihx : %.ast
	$(AS) -l -o $*.rel $<
	$(LD) -n -i -b _CODE=0x0200 -b _DATA=0x8000 $* $*.rel; test -f $*.ihx

# -----------------------------------------------------------------------
# Targets
# -----------------------------------------------------------------------
.PHONY: all all_func clean

all: $(VERIF_VMEM)

all_func: all $(FUNC_VMEM)

# Explicit targets so C-compiled files aren't displaced by SDCC's
# intermediate .asm output on subsequent builds.
hello.ihx: hello.c
	$(CC) $<

fib.ihx: fib.c
	$(CC) $<

%.ihx : %.c
	$(CC) $<

# bintr requires its dedicated C runtime crt0
bintr_crt0.rel: bintr_crt0.asm
	$(AS) -l -o bintr_crt0.rel $<

bintr.ihx: bintr.c bintr_crt0.rel
	$(CC) --no-std-crt0 $^ -- -m -j -x

clean:
	rm -f *.rel *.ihx *.vmem *.lnk *.map *.sym *.rst *.noi *.lk
	rm -f fib.asm bintr.asm hello.asm

# distclean also removes listing files (kept by clean for debugging)
distclean: clean
	rm -f *.lst
