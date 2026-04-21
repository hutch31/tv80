---
name: run-tests
description: 'Run TV80 verification tests using Cocotb and Verilator. Use when: running simulations, executing testbench, building test programs, checking test results, running a specific test case, collecting coverage.'
argument-hint: '[test name or "all"]'
---

# Run TV80 Verification Tests

## When to Use
- Run all or specific Cocotb simulation tests
- Build Z80 assembly test programs into `.vmem` format
- Check test results and coverage
- Debug test failures

## Environment
- Simulator: **Verilator** + **Cocotb**
- Test programs: `verif/tests/` (Z80 assembly, built with `make`)
- Testbench: `verif/env/` (Python/Cocotb, run with `make`)
- Results: `verif/env/results.xml`
- Coverage: `verif/env/coverage_annotated/`

## Procedure

### Step 1 – Build test programs (if not already built)
```pwsh
podman run -it -v /c/Users/Guy/Documents/tv80:/app -w /app tvtools sh -c "(cd verif/tests; make)"
```
This compiles all `.asm` files into `.vmem` Verilog memory images.

### Step 2 – Run all tests
```pwsh
podman run -v /c/Users/Guy/Documents/tv80:/app -w /app tvtools sh -c "cd verif/env && make SIM=verilator TOPLEVEL=tb_top MODULE=testbench 2>&1"
```

### Step 3 – Run a single test
```pwsh
podman run -v /c/Users/Guy/Documents/tv80:/app -w /app tvtools sh -c "cd verif/env && make SIM=verilator TOPLEVEL=tb_top MODULE=testbench TESTCASE=<test name> 2>&1"
```
Example test names: `rst_01_reset_basic`, `alu_01_add`, `int_im1_basic`

### Step 4 – Generate coverage report
```pwsh
podman run -it -v /c/Users/Guy/Documents/tv80:/app -w /app tvtools sh -c "(cd verif/env; make coverage)"
```
Coverage report is written to `verif/env/coverage_annotated/`.

### Step 5 – Check results
- Pass/fail summary: `verif/env/results.xml`
- Cocotb log output is printed to the terminal during the run

## Notes
- Always run from the root directory of the project
- The `TESTS_DIR` environment variable is set automatically by the env Makefile
- Requires: `cocotb==1.8.x`, Verilator 5.x, Python 3.8+, `sdcc`/`sdasz80`
- Do **not** modify RTL files in `rtl/`; only create/modify files in `verif/`
