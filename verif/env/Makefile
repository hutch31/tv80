# Cocotb + Verilator Makefile for TV80 verification
#
# Usage:
#   make              – run all tests
#   make TESTCASE=rst_01_reset_basic – run a single test
#   make coverage     – generate coverage report after test run
#   make RTL_VARIANT=chisel – use Chisel-generated RTL (rtl/generated)
#
# Requirements:
#   - cocotb  1.8.x  (pip install cocotb==1.8.1)
#   - Verilator 5.x  (built from source or package)
#   - Python 3.8+
#
# Set TESTS_DIR to the compiled .vmem directory if it differs from the
# default (../tests relative to this Makefile).

SIM            ?= verilator
TOPLEVEL_LANG  ?= verilog

REPO_ROOT := $(abspath ../..)
RTL_DIR   := $(REPO_ROOT)/rtl/core
RTL_GEN_DIR := $(REPO_ROOT)/rtl/generated
TESTS_DIR := $(abspath ../tests)
RTL_VARIANT ?= original

# Optional alias: allow TESTNAME=<cocotb test function> in addition to TESTCASE
ifdef TESTNAME
TESTCASE ?= $(TESTNAME)
endif

# All RTL source files
VERILOG_SOURCES  = $(abspath tb_top.v)

ifeq ($(RTL_VARIANT),chisel)
VERILOG_SOURCES += $(abspath tv80s_chisel_compat.sv)
VERILOG_SOURCES += $(RTL_GEN_DIR)/Tv80s.sv
VERILOG_SOURCES += $(RTL_GEN_DIR)/Tv80Core.sv
VERILOG_SOURCES += $(RTL_GEN_DIR)/Tv80Mcode.sv
VERILOG_SOURCES += $(RTL_GEN_DIR)/Tv80Alu.sv
VERILOG_SOURCES += $(RTL_GEN_DIR)/Tv80Reg.sv
EXTRA_ARGS += -DTV80_USE_CHISEL
else
# order matters: tv80s instantiates tv80_core etc.
VERILOG_SOURCES += $(RTL_DIR)/tv80s.v
VERILOG_SOURCES += $(RTL_DIR)/tv80_core.v
VERILOG_SOURCES += $(RTL_DIR)/tv80_mcode.v
VERILOG_SOURCES += $(RTL_DIR)/tv80_alu.v
VERILOG_SOURCES += $(RTL_DIR)/tv80_reg.v
endif

TOPLEVEL = tb_top
MODULE   = testbench

# Pass the test program directory so testbench.py can locate .vmem files
export TESTS_DIR

# -----------------------------------------------------------------------
# Verilator-specific options
# -----------------------------------------------------------------------
# --public-flat-rw  Expose all signals (including ROM/RAM arrays) for cocotb
# --coverage        Instrument for line + branch coverage
# -Wno-WIDTHTRUNC   Suppress harmless width-truncation warnings
# -Wno-CASEINCOMPLETE Suppress case-incomplete warnings common in RTL
EXTRA_ARGS += --public-flat-rw
EXTRA_ARGS += --coverage --coverage-toggle --coverage-underscore
EXTRA_ARGS += --timing
EXTRA_ARGS += -Wno-WIDTHTRUNC
EXTRA_ARGS += -Wno-CASEINCOMPLETE
EXTRA_ARGS += -Wno-UNOPTFLAT

# Enable VCD waveform dump when WAVES=1
ifeq ($(WAVES),1)
EXTRA_ARGS += --trace
EXTRA_ARGS += -DTV80_WAVES
endif

# -----------------------------------------------------------------------
# Run all tests and then produce a merged coverage report
# -----------------------------------------------------------------------
.PHONY: coverage clean_cov

coverage: sim
	@echo "=== Generating coverage report ==="
	@COV_DATA=$$(ls -t sim_build/coverage.dat coverage.dat 2>/dev/null | head -n 1); \
	if [ -z "$$COV_DATA" ]; then \
		echo "%Error: Can't read coverage.dat or sim_build/coverage.dat"; \
		exit 1; \
	fi; \
	echo "Using coverage data: $$COV_DATA (RTL_VARIANT=$(RTL_VARIANT))"; \
	verilator_coverage --annotate coverage_annotated \
	    --annotate-all \
	    --annotate-min 1 \
	    $$COV_DATA
	@echo "Coverage report written to coverage_annotated/"

# Build all test programs (verif + func) before running simulations.
# GNU Make allows adding prerequisites to targets defined in included files.
.PHONY: vmem_build
vmem_build:
	$(MAKE) -C $(TESTS_DIR) all_func

sim: vmem_build

# Standard cocotb include (must be last)
include $(shell cocotb-config --makefiles)/Makefile.sim
