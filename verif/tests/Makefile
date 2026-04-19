# Makefile for TV80 verification test programs
#
# Builds Z80 assembly test programs into Verilog memory (.vmem) format
# that the cocotb testbench can $readmemh / array-write into ROM.
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

CC   := sdcc -mz80 -I$(TESTS_SRC) -I../../sc_env -I.
AS   := sdasz80
IHEX2MEM := python3 $(SCRIPTS_DIR)/ihex2mem.py

# Linker options for pure-assembly programs (no C runtime)
AS_LINK_OPTIONS := -- -m -j -x

# -----------------------------------------------------------------------
# New verification test programs (in verif/tests/)
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
    wait_test

VERIF_VMEM := $(addsuffix .vmem, $(VERIF_TESTS))

# -----------------------------------------------------------------------
# Functional tests – built from ../../tests/ source
# -----------------------------------------------------------------------
FUNC_TESTS_AST := alu_optest load_optest otir ivec_flags
FUNC_TESTS_ASM := basic_int
FUNC_TESTS_C   := hello fib

FUNC_VMEM := $(addsuffix .vmem, $(FUNC_TESTS_AST) $(FUNC_TESTS_ASM) $(FUNC_TESTS_C) bintr)

# -----------------------------------------------------------------------
# Pattern rules
# -----------------------------------------------------------------------

# Pure assembly → ihex via sdasz80 + sdcc linker
%.rel : %.asm
	$(AS) -l -o $*.rel $<

%.rel : %.ast
	$(AS) -l -o $*.rel $<

%.ihx : %.rel
	$(CC) --no-std-crt0 $*.rel $(AS_LINK_OPTIONS)

%.vmem : %.ihx
	$(IHEX2MEM) $< $@

# -----------------------------------------------------------------------
# Targets
# -----------------------------------------------------------------------
.PHONY: all all_func clean

all: $(VERIF_VMEM)

all_func: all $(FUNC_VMEM)

# Functional test sources live in ../../tests/ – copy .rel then link
$(FUNC_TESTS_AST:=.rel) : $(FUNC_TESTS_AST:=.ast)
	$(AS) -l -o $*.rel $(TESTS_SRC)/$*.ast

$(FUNC_TESTS_ASM:=.rel) : $(FUNC_TESTS_ASM:=.asm)
	$(AS) -l -o $*.rel $(TESTS_SRC)/$*.asm

# bintr needs its C runtime assembly object too
bintr_crt0.rel:
	$(AS) -l -o bintr_crt0.rel $(TESTS_SRC)/bintr_crt0.asm

bintr.rel: bintr_crt0.rel
	$(CC) -c $(TESTS_SRC)/bintr.c -o bintr.rel || \
	$(AS) -l -o bintr.rel $(TESTS_SRC)/bintr.asm

bintr.ihx: bintr.rel bintr_crt0.rel
	$(CC) --no-std-crt0 bintr.rel bintr_crt0.rel $(AS_LINK_OPTIONS)

# C test programs
%.ihx : $(TESTS_SRC)/%.c
	$(CC) $<

clean:
	rm -f *.rel *.ihx *.vmem *.lnk *.map *.lst *.sym *.rst
