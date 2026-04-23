# TV80 Processor Verification Test Plan

## 1. Overview

This document describes the verification plan for the TV80 Z80-compatible processor core (`tv80s` / `tv80_core`). The plan covers the functional test strategy, the coverage goals, and the individual test cases that must be implemented.

The verification environment uses [Cocotb](https://www.cocotb.org/) as the Python-based testbench framework and [Verilator](https://www.veripool.org/verilator/) as the RTL simulator. Line and branch coverage are collected via Verilator's built-in coverage instrumentation.

### 1.1 Coverage Goals

| Metric | Goal |
|--------|------|
| Line coverage | ≥ 99% |
| Branch coverage | ≥ 90% |

---

## 2. Design Under Test

| Module | File | Description |
|--------|------|-------------|
| `tv80s` | `rtl/core/tv80s.v` | Top-level synchronous Z80 wrapper |
| `tv80_core` | `rtl/core/tv80_core.v` | Core pipeline and control |
| `tv80_mcode` | `rtl/core/tv80_mcode.v` | Microcode sequencer |
| `tv80_alu` | `rtl/core/tv80_alu.v` | Arithmetic/Logic Unit |
| `tv80_reg` | `rtl/core/tv80_reg.v` | Register file |

---

## 3. Verification Environment

### 3.1 Architecture

The testbench mirrors the legacy `env/tb_top.v` structure:

- **DUT** – `tv80s` instantiated with a synchronous clock and active-low reset.
- **ROM** – `async_mem` loaded from a compiled Z80 program (`.vmem` hex file).
- **RAM** – `async_mem` mapped to upper half of address space (`A[15]=1`).
- **IO model** – Cocotb-side coroutine that responds to Z80 `iorq_n`/`rd_n`/`wr_n` cycles on the port addresses defined in `sc_env/tv80_scenv.h`.

### 3.2 IO Port Map

All ports are accessed via Z80 `IN`/`OUT` instructions. The Cocotb `io_model` coroutine implements the port behaviour in software.

#### Control / Status Ports

| Port | Address | Dir | Description |
|------|---------|-----|-------------|
| `SIM_CTL_PORT` | `0x80` | W | Write `0x01` → signal **PASS** and end test. Write `0x02` → signal **FAIL** and end test. |
| `MSG_PORT` | `0x81` | W | Write a byte to emit a character. A newline (`0x0A`) flushes the buffer to the simulation log as `PROGRAM: <text>`. |

#### Timeout Control Ports

The timeout counter increments every clock cycle while enabled. When it reaches `max_timeout` the test is marked **TIMEOUT**.

| Port | Address | Dir | Description |
|------|---------|-----|-------------|
| `TIMEOUT_PORT` | `0x82` | R/W | Bit 0: counter enable (1=run, 0=freeze). Bit 1: counter reset (write 1 to clear to zero). Read returns current control byte. |
| `MAX_TIMEOUT_LOW` | `0x83` | R/W | Low byte of the 16-bit timeout threshold (clock cycles). |
| `MAX_TIMEOUT_HIGH` | `0x84` | R/W | High byte of the 16-bit timeout threshold. Default: `0x01F4` (500 cycles). |

#### Interrupt Generation Ports

| Port | Address | Dir | Description |
|------|---------|-----|-------------|
| `INTR_CNTDWN` | `0x90` | R/W | Write N > 0: start countdown; `int_n` asserts low after N cycles. Write 0: disable. Read: current countdown value. `int_n` is automatically deasserted when the CPU performs an INT-acknowledge cycle. |
| `NMI_CNTDWN` | `0x95` | R/W | Write N > 0: start countdown; `nmi_n` pulses low for one cycle after N cycles. Write 0: disable. Read: current countdown value. NMI is edge-triggered, so it fires exactly once per write. |
| `NMI_TRIG_OPCODE` | `0xA0` | R/W | Write an opcode byte. When the CPU's instruction register (`IR`) matches this value, `nmi_n` is pulsed low for one cycle. Write `0x00` to disable. |

#### Utility / Data Ports

| Port | Address | Dir | Description |
|------|---------|-----|-------------|
| `CKSUM_VALUE` | `0x91` | R/W | Read or set the 8-bit running checksum register directly. |
| `CKSUM_ACCUM` | `0x92` | W | Add the written byte to the checksum register (modulo 256). Useful for verifying data sequences without a subtract loop. |
| `INC_ON_READ` | `0x93` | R/W | Write to set a value; each subsequent read returns the current value then increments it by 1 (wraps at 255). Useful for testing IN loops. |
| `RANDVAL` | `0x94` | R | Returns the next byte from a simple LCG pseudo-random sequence. The seed is re-randomised each simulation run. |


### 3.3 Test Control Protocol

All tests are Z80 programs that:

1. Perform their functional operations.
2. Write `0x01` to `SIM_CTL_PORT` (0x80) to signal **PASS**.
3. Write `0x02` to `SIM_CTL_PORT` (0x80) to signal **FAIL**.
4. The Cocotb monitor detects this write and ends simulation with a pass/fail result.

### 3.4 Directory Layout

```
verif/
  doc/          ← This document and other documentation
  env/          ← Cocotb testbench (Python) and Verilog wrapper
  tests/        ← Z80 assembly and C test programs
  bugs/         ← Bug reports (one file per bug)
```

### 3.5 Mapping Plan Test Names to Simulation `TESTNAME`

The test names shown in Section 4 are plan-level names. In simulation, select tests by the Cocotb test function name.

- `TESTNAME` is the selector value shown below.
- In this Make-based flow, pass it as `TESTCASE=<TESTNAME>`.

Example:

```sh
make -C verif/env SIM=verilator TOPLEVEL=tb_top MODULE=testbench TESTCASE=rst_01_reset_basic
```

Chisel variant example:

```sh
make -C verif/env RTL_VARIANT=chisel SIM=verilator TOPLEVEL=tb_top MODULE=testbench TESTCASE=rst_01_reset_basic
```

| Plan IDs | Plan Test Name(s) | Simulation `TESTNAME` (`TESTCASE` value) |
|----------|-------------------|--------------------------------------------|
| RST-01 | `reset_basic` | `rst_01_reset_basic` |
| RST-02 | `reset_reapply` | `rst_02_reset_reapply` |
| RST-03 | `reset_signals` | `rst_03_reset_signals` |
| ALU-01..ALU-11 | `alu_add`, `alu_adc`, `alu_sub`, `alu_sbc`, `alu_inc_dec`, `alu_daa`, `alu_cp` | `alu_01_to_11_arithmetic` |
| ALU-05..ALU-07 | `alu_add16`, `alu_adc16`, `alu_sbc16` | `alu_05_to_07_arith16` |
| LOG-01..LOG-07 | `alu_and`, `alu_or`, `alu_xor`, `alu_cpl`, `alu_ccf`, `alu_scf`, `alu_neg` | `log_01_to_07_logic` |
| ROT-01..ROT-05 | `rlca_rrca`, `rla_rra`, `rl_rr_rrc_rlc`, `sla_sra_srl`, `rld_rrd` | `rot_01_to_05_rotate` |
| BIT-01..BIT-03 | `bit_test`, `bit_set`, `bit_res` | `bit_01_to_03_bit_ops` |
| LD-01..LD-06 | `load_r_r`, `load_r_n`, `load_r_hl`, `load_hl_r`, `load_r_ix_iy`, `load_ix_iy_r` | `ld_01_to_06_load_reg` |
| LD-07..LD-14 | `load_a_indirect`, `load_indirect_a`, `load_rr_nn`, `load_hl_nn_indirect`, `load_rr_nn_indirect`, `load_sp_hl`, `load_i_r`, `load_block` | `ld_07_to_14_load_mem` |
| JMP-01..JMP-08 | `jump_unconditional`, `jump_relative`, `jump_conditional`, `djnz`, `call_ret`, `call_ret_conditional`, `rst`, `retn_reti` | `jmp_01_to_08_jumps` |
| IO-01..IO-03 | `in_out_basic`, `in_out_c`, `io_block` | `io_01_to_03_io_ops` |
| STK-01..STK-02 | `push_pop`, `ex_sp` | `stk_01_02_stack` |
| EXC-01..EXC-03 | `ex_af`, `exx`, `ex_de_hl` | `exc_01_to_03_exchange` |
| MISC-01..MISC-03 | `nop`, `halt`, `di_ei` | `misc_01_to_03_misc` |
| INT-01 | `int_mode0` | `int_01_mode0` |
| INT-02 | `int_mode1` | `int_02_mode1` |
| INT-03 | `int_mode2` | `int_03_mode2` |
| NMI-01..NMI-05 | `nmi_basic`, `nmi_retn`, `nmi_during_halt`, `nmi_priority`, `nmi_opcode_trigger` | `nmi_01_to_05_nmi` |
| BUS-01 | `busrq_basic` | `bus_01_busrq_basic` |
| BUS-02 | `busrq_release` | `bus_02_busrq_release` |
| WAIT-01 | `wait_state` | `wait_01_memory_wait` |
| WAIT-02 | `wait_io` | `wait_02_io_wait` |
| FUNC-01 | `hello_world` | `func_01_hello_world` |
| FUNC-02 | `fibonacci` | `func_02_fibonacci` |
| FUNC-05 | `alu_optest` | `func_05_alu_optest` |
| FUNC-06 | `load_optest` | `func_06_load_optest` |

---

## 4. Test Groups and Test Cases

### 4.1 Reset and Initialization

**Purpose:** Verify the processor initializes correctly after reset deassertion.

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| RST-01 | `reset_basic` | Assert reset for 20 cycles, then deassert. DUT must begin instruction fetch from address 0x0000. | `m1_n` asserts and `A` is 0x0000 on first fetch after reset |
| RST-02 | `reset_reapply` | Run a short program, reapply reset mid-execution, verify PC returns to 0x0000. | No stale state; program restarts cleanly |
| RST-03 | `reset_signals` | Check that all bus-control outputs (`mreq_n`, `iorq_n`, `rd_n`, `wr_n`, `busak_n`) are deasserted during reset. | All outputs deasserted while `reset_n=0` |

---

### 4.2 ALU – Arithmetic Operations

**Purpose:** Verify correct computation and flag updates for all arithmetic instructions.

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| ALU-01 | `alu_add` | ADD A,r / ADD A,n for all register operands and immediate; boundary values (0x00, 0x7F, 0x80, 0xFF). | Correct result in A; C, H, Z, S, P/V flags correct |
| ALU-02 | `alu_adc` | ADC A,r / ADC A,n with carry=0 and carry=1. | Carry propagation correct |
| ALU-03 | `alu_sub` | SUB r / SUB n; result, N flag set, borrow cases. | Result and flags correct |
| ALU-04 | `alu_sbc` | SBC A,r / SBC A,n with borrow=0 and borrow=1. | Borrow propagation correct |
| ALU-05 | `alu_add16` | ADD HL,rr; carry out of bit 15, H flag from bit 11. | 16-bit result correct; S, Z, P/V preserved |
| ALU-06 | `alu_adc16` | ADC HL,rr; all register pairs; S, Z, P/V updated. | All flags correct |
| ALU-07 | `alu_sbc16` | SBC HL,rr; all register pairs; N=1. | All flags correct |
| ALU-08 | `alu_inc_dec` | INC r, DEC r for all registers; no carry flag change; H and Z correct. | Flags correct; carry unchanged |
| ALU-09 | `alu_inc_dec16` | INC rr, DEC rr; no flags affected. | 16-bit registers increment/decrement correctly |
| ALU-10 | `alu_daa` | DAA after ADD and SUB; BCD adjustment correct. | Result is valid BCD; C, H, Z, S, P flags correct |
| ALU-11 | `alu_cp` | CP r / CP n; result discarded, flags set. | Flags as for SUB; A unchanged |

---

### 4.3 ALU – Logical Operations

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| LOG-01 | `alu_and` | AND r / AND n; H=1, N=0, C=0, P=parity. | Result and flags correct |
| LOG-02 | `alu_or` | OR r / OR n; H=0, N=0, C=0, P=parity. | Result and flags correct |
| LOG-03 | `alu_xor` | XOR r / XOR n; H=0, N=0, C=0, P=parity. | Result and flags correct |
| LOG-04 | `alu_cpl` | CPL; A = ~A; H=1, N=1; other flags preserved. | All conditions correct |
| LOG-05 | `alu_ccf` | CCF; carry flipped, H=old carry, N=0. | Flag behavior correct |
| LOG-06 | `alu_scf` | SCF; C=1, H=0, N=0; S, Z, P/V preserved. | Flag behavior correct |
| LOG-07 | `alu_neg` | NEG (ED prefix); A = 0-A; N=1, all flags. | Result and flags correct |

---

### 4.4 ALU – Rotate and Shift Operations

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| ROT-01 | `rlca_rrca` | RLCA / RRCA; rotate A through carry; H=0, N=0. | Carry and result correct |
| ROT-02 | `rla_rra` | RLA / RRA; rotate A through carry flag. | Carry and result correct |
| ROT-03 | `rl_rr_rrc_rlc` | CB-prefix RLC/RRC/RL/RR on all registers and (HL). | All affected registers rotate correctly |
| ROT-04 | `sla_sra_srl` | CB-prefix SLA/SRA/SRL on all registers and (HL). | Shift result and flags correct |
| ROT-05 | `rld_rrd` | RLD / RRD; rotate nibbles between A and (HL). | Nibble rotation correct; H=0, N=0, P=parity |

---

### 4.5 ALU – Bit Operations

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| BIT-01 | `bit_test` | BIT b,r / BIT b,(HL) for all bits 0–7; Z flag reflects complement of tested bit. | Z, H=1, N=0 correct |
| BIT-02 | `bit_set` | SET b,r / SET b,(HL) for all bits 0–7. | Correct bit set; other bits unchanged |
| BIT-03 | `bit_res` | RES b,r / RES b,(HL) for all bits 0–7. | Correct bit cleared; other bits unchanged |

---

### 4.6 Load Operations

**Purpose:** Verify all 8-bit and 16-bit load instructions.

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| LD-01 | `load_r_r` | LD r,r' for all 56 register-to-register combinations (excl. (HL),(HL)). | Destination gets source value |
| LD-02 | `load_r_n` | LD r,n for each register; immediate byte loaded correctly. | Register contains immediate value |
| LD-03 | `load_r_hl` | LD r,(HL) for all registers. | Register loaded from memory at HL |
| LD-04 | `load_hl_r` | LD (HL),r for all registers. | Memory at HL written with register value |
| LD-05 | `load_r_ix_iy` | LD r,(IX+d) / LD r,(IY+d); displacement range. | Register loaded from offset address |
| LD-06 | `load_ix_iy_r` | LD (IX+d),r / LD (IY+d),r. | Memory written at offset address |
| LD-07 | `load_a_indirect` | LD A,(BC) / LD A,(DE) / LD A,(nn). | A loaded from indirect/absolute address |
| LD-08 | `load_indirect_a` | LD (BC),A / LD (DE),A / LD (nn),A. | A written to indirect/absolute address |
| LD-09 | `load_rr_nn` | LD BC/DE/HL/SP,nn; immediate 16-bit. | Register pair loaded correctly |
| LD-10 | `load_hl_nn_indirect` | LD HL,(nn) / LD (nn),HL. | 16-bit load/store from/to absolute address |
| LD-11 | `load_rr_nn_indirect` | LD rr,(nn) / LD (nn),rr (ED prefix). | All register pairs covered |
| LD-12 | `load_sp_hl` | LD SP,HL; LD SP,IX; LD SP,IY. | SP updated correctly |
| LD-13 | `load_i_r` | LD I,A / LD A,I; LD R,A / LD A,R (ED prefix). | Special registers loaded; IFF2 copied to P on LD A,I/R |
| LD-14 | `load_block` | LDI, LDD, LDIR, LDDR; block transfer. | BC decremented; DE/HL incremented/decremented; P/V flag; BC=0 check |

---

### 4.7 Jump, Call, and Return Instructions

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| JMP-01 | `jump_unconditional` | JP nn; JP (HL); JP (IX); JP (IY). | PC set to target address |
| JMP-02 | `jump_relative` | JR e; JR cc,e; correct displacement (signed byte). | PC offset correctly; taken and not-taken |
| JMP-03 | `jump_conditional` | JP cc,nn for all eight conditions (NZ/Z/NC/C/PO/PE/P/M). | Taken when condition true; not-taken otherwise |
| JMP-04 | `djnz` | DJNZ e; B decremented; branch while B≠0. | Loop terminates exactly when B=0 |
| JMP-05 | `call_ret` | CALL nn; RET; correct stack push/pop of PC. | Return address correct; SP restored |
| JMP-06 | `call_ret_conditional` | CALL cc,nn / RET cc for all conditions. | Taken and not-taken paths verified |
| JMP-07 | `rst` | RST 0x00–0x38 (8 vectors); correct target address. | PC set to RST vector; stack correct |
| JMP-08 | `retn_reti` | RETN / RETI; IFF1 restored; return from NMI/INT. | IFF1 correct after return |

---

### 4.8 Input/Output Instructions

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| IO-01 | `in_out_basic` | OUT (n),A / IN A,(n). | iorq_n asserted; address on A bus; data transferred |
| IO-02 | `in_out_c` | IN r,(C) / OUT (C),r for all registers; flags from IN. | Register contents and Z,S,P flags correct |
| IO-03 | `io_block` | INI, IND, INIR, INDR, OUTI, OUTD, OTIR, OTDR; block I/O. | B decremented; HL updated; Z flag when B=0 |

---

### 4.9 Stack Operations

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| STK-01 | `push_pop` | PUSH/POP for AF, BC, DE, HL, IX, IY. | SP adjusted correctly; data preserved |
| STK-02 | `ex_sp` | EX (SP),HL / EX (SP),IX / EX (SP),IY. | Memory and register values exchanged |

---

### 4.10 Exchange Instructions

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| EXC-01 | `ex_af` | EX AF,AF'; alternate AF visible after exchange. | Both banks toggled correctly |
| EXC-02 | `exx` | EXX; alternate BC, DE, HL banks. | Both banks toggled correctly |
| EXC-03 | `ex_de_hl` | EX DE,HL. | DE and HL swapped |

---

### 4.11 Miscellaneous Instructions

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| MISC-01 | `nop` | NOP; PC advances by 1; no other state changes. | No side effects |
| MISC-02 | `halt` | HALT; CPU enters halt state; continues on INT/NMI. | `halt_n` deasserted; exits halt on interrupt |
| MISC-03 | `di_ei` | DI / EI; interrupt enable flip-flop. | INT not accepted after DI; accepted after EI |

---

### 4.12 Interrupt Handling – Maskable Interrupt (INT)

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| INT-01 | `int_mode0` | IM 0; INT accepted; CPU fetches instruction from data bus (RST injected). | RST vector executed; return to correct PC |
| INT-02 | `int_mode1` | IM 1; INT accepted; CPU jumps to 0x0038. | PC = 0x0038; stack has return address |
| INT-03 | `int_mode2` | IM 2; interrupt vector table; CPU forms address from I register + data bus byte. | Correct ISR address fetched from vector table |
| INT-04 | `int_nested` | EI inside ISR; re-entrant interrupt (mode 1). | Nested INT handled; stack depth correct |
| INT-05 | `int_ei_delay` | Verify INT is not recognized until instruction after EI completes. | One instruction executed before INT accepted |
| INT-06 | `int_reti` | RETI terminates interrupt; IFF1/IFF2 restored. | Interrupt enable restored after RETI |

---

### 4.13 Interrupt Handling – Non-Maskable Interrupt (NMI)

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| NMI-01 | `nmi_basic` | Assert NMI; CPU jumps to 0x0066; IFF1 cleared. | PC = 0x0066; IFF1 = 0; IFF2 preserves old IFF1 |
| NMI-02 | `nmi_retn` | RETN at end of NMI handler; IFF1 restored from IFF2. | IFF1 restored; return address correct |
| NMI-03 | `nmi_during_halt` | Assert NMI while HALT active; CPU exits halt and jumps to 0x0066. | Halt exits; NMI handler executes |
| NMI-04 | `nmi_priority` | Assert both INT and NMI simultaneously; NMI has priority. | NMI handled first |
| NMI-05 | `nmi_opcode_trigger` | Use `NMI_TRIG_OPCODE` IO port; NMI triggered on specific opcode. | NMI fires when IR matches trigger |

---

### 4.14 Bus Request / Bus Acknowledge

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| BUS-01 | `busrq_basic` | Assert `busrq_n`; verify `busak_n` asserts; bus signals tri-stated. | `busak_n` low within a few cycles; A, data, control floated |
| BUS-02 | `busrq_release` | Deassert `busrq_n`; CPU resumes execution from correct PC. | Execution continues without error |

---

### 4.15 Wait State Insertion

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| WAIT-01 | `wait_state` | Assert `wait_n=0` during a memory read; verify CPU holds T-state. | Extra clock cycles inserted; data sampled correctly |
| WAIT-02 | `wait_io` | Assert `wait_n=0` during an I/O cycle. | Wait states inserted in I/O cycle |

---

### 4.16 Functional / Integration Tests

| ID | Test Name | Description | Pass Criteria |
|----|-----------|-------------|---------------|
| FUNC-01 | `hello_world` | Run `tests/hello.c` compiled program; verify character output via `MSG_PORT`. | "Hello, world!" appears in log |
| FUNC-02 | `fibonacci` | Run `tests/fib.c`; verify Fibonacci numbers 1–19 correct. | All 19 values match golden reference |
| ~~FUNC-03~~ | ~~`basic_interrupt`~~ | ~~Run `tests/basic_int.asm`~~; interrupt coverage provided by directed tests int_01–03 and nmi_01–05. | Removed — covered by directed tests |
| ~~FUNC-04~~ | ~~`bintr`~~ | ~~Run `tests/bintr.asm`~~; interrupt/NMI coverage provided by directed tests int_01–03 and nmi_01–05. | Removed — covered by directed tests |
| FUNC-05 | `alu_optest` | Run `tests/alu_optest.ast`; comprehensive ALU self-test. | Test pass written |
| FUNC-06 | `load_optest` | Run `tests/load_optest.ast`; comprehensive load self-test. | Test pass written |
| ~~FUNC-07~~ | ~~`otir_test`~~ | ~~Run `tests/otir.ast`~~; OTIR/OTDR/INIR/INDR coverage provided by directed test io_01_to_03 (IO-03). | Removed — covered by directed tests |

---

## 5. Coverage Closure Strategy

1. After each test run, collect Verilator coverage data (`verilator_coverage`).
2. Merge coverage from all tests into a single database.
3. Identify uncovered lines and branches in `tv80_core.v`, `tv80_mcode.v`, `tv80_alu.v`, and `tv80_reg.v`.
4. Add targeted tests (or extend existing ones) to cover identified gaps.
5. Iterate until coverage goals (99% line / 90% branch) are met.

Known hard-to-cover areas to target explicitly:

- `TV80_REFRESH` ifdef path (disabled by default; may need a separate build).
- `ISet` = 2'b01 (CB prefix), 2'b10 (ED prefix), 2'b11 (DD/FD prefix) – require IX/IY and extended instruction tests.
- All 8 conditional branch conditions in both taken and not-taken paths.
- DAA after both addition and subtraction with various H/C combinations.
- Block instructions with zero-iteration case (BC=0 on entry to LDIR/LDDR/INIR/etc.).

---

## 6. Bug Reporting

When a test reveals incorrect RTL behavior, a bug report is filed in `verif/bugs/` with the naming convention `BUG-NNN-<short-description>.md`.

Each report contains:

- **Summary** – one-line description of the defect.
- **Observed Behavior** – what the simulation shows.
- **Expected Behavior** – what the Z80 specification requires.
- **Method to Reproduce** – test name, command line, and relevant waveform signals.

---

## 7. Revision History

| Date | Author | Description |
|------|--------|-------------|
| 2026-04-23 | Copilot Verification Agent | Added mapping from plan test names/IDs to simulation `TESTNAME` (`TESTCASE`) selectors |
| 2026-04-19 | Copilot Verification Agent | Initial test plan created |
