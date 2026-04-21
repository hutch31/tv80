# Cocotb + Verilator Makefile for TV80 verification
#
# Usage:
#   make              – run all tests
#   make TESTCASE=rst_01_reset_basic – run a single test
#   make coverage     – generate coverage report after test run
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
TESTS_DIR := $(abspath ../tests)

# All RTL source files (order matters: tv80s instantiates tv80_core etc.)
VERILOG_SOURCES  = $(abspath tb_top.v)
VERILOG_SOURCES += $(RTL_DIR)/tv80s.v
VERILOG_SOURCES += $(RTL_DIR)/tv80_core.v
VERILOG_SOURCES += $(RTL_DIR)/tv80_mcode.v
VERILOG_SOURCES += $(RTL_DIR)/tv80_alu.v
VERILOG_SOURCES += $(RTL_DIR)/tv80_reg.v

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
EXTRA_ARGS += --coverage
EXTRA_ARGS += -Wno-WIDTHTRUNC
EXTRA_ARGS += -Wno-CASEINCOMPLETE
EXTRA_ARGS += -Wno-UNOPTFLAT

# Enable VCD waveform dump when WAVES=1
ifeq ($(WAVES),1)
EXTRA_ARGS += --trace
endif

# -----------------------------------------------------------------------
# Run all tests and then produce a merged coverage report
# -----------------------------------------------------------------------
.PHONY: coverage clean_cov

coverage: sim
	@echo "=== Generating coverage report ==="
	verilator_coverage --annotate coverage_annotated \
	    --annotate-min 1 \
	    sim_build/coverage.dat || true
	@echo "Coverage report written to coverage_annotated/"

# Standard cocotb include (must be last)
include $(shell cocotb-config --makefiles)/Makefile.sim
