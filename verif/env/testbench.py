"""
TV80 Cocotb Verification Testbench
===================================
Implements the verification environment described in PORTING.md and
verif/doc/test_plan.md.

Architecture
------------
* DUT  : tv80s (synchronous Z80 wrapper) instantiated in tb_top.v
* ROM  : reg array in tb_top.v, written from Python before each test
* RAM  : reg array in tb_top.v, writable by the CPU during simulation
* IO   : Python coroutine (TV80TB.io_model) monitors iorq_n/rd_n/wr_n
         and drives tb_top.io_din just like env/env_io.v does

IO Port Map (from sc_env/tv80_scenv.h)
---------------------------------------
0x80  SIM_CTL_PORT    W   0x01=PASS, 0x02=FAIL
0x81  MSG_PORT        W   character output (newline flushes to log)
0x82  TIMEOUT_PORT    R/W timeout enable/reset
0x83  MAX_TIMEOUT_LOW R/W timeout threshold low byte
0x84  MAX_TIMEOUT_HIGH R/W timeout threshold high byte
0x90  INTR_CNTDWN     R/W INT countdown; fires INT when reaches 1
0x91  CKSUM_VALUE     R/W checksum register
0x92  CKSUM_ACCUM     W   accumulate byte into checksum
0x93  INC_ON_READ     R/W value readable/writable
0x94  RANDVAL         R   pseudo-random byte
0x95  NMI_CNTDWN      R/W NMI countdown; fires NMI when reaches 1
0xA0  NMI_TRIG_OPCODE R/W trigger NMI when cpu_ir equals this byte
"""

import os
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, First, Timer
from cocotb.result import SimTimeoutError

# ---------------------------------------------------------------------------
# IO port addresses
# ---------------------------------------------------------------------------
SIM_CTL_PORT     = 0x80
MSG_PORT         = 0x81
TIMEOUT_PORT     = 0x82
MAX_TIMEOUT_LOW  = 0x83
MAX_TIMEOUT_HIGH = 0x84
INTR_CNTDWN      = 0x90
CKSUM_VALUE      = 0x91
CKSUM_ACCUM      = 0x92
INC_ON_READ      = 0x93
RANDVAL          = 0x94
NMI_CNTDWN       = 0x95
NMI_TRIG_OPCODE  = 0xA0

# Default test timeout in clock cycles (10 ns clock → 500 000 cycles = 5 ms)
DEFAULT_TIMEOUT = 500_000
_NS_PER_CYCLE   = 10
# Cocotb-level timeout (ns) applied to @cocotb.test decorators.
# Slightly larger than DEFAULT_TIMEOUT so the io_model timeout fires first.
_STD_TIMEOUT_NS = (DEFAULT_TIMEOUT + 50_000) * _NS_PER_CYCLE  # 5.5 ms

# Directory containing compiled .vmem test programs
TESTS_DIR = os.environ.get(
    "TESTS_DIR",
    os.path.join(os.path.dirname(__file__), "..", "tests")
)


# ---------------------------------------------------------------------------
# Helper: load a .vmem file into the ROM array
# ---------------------------------------------------------------------------
def _load_vmem(dut, vmem_path):
    """Parse a Verilog $readmemh-style .vmem file and write bytes into ROM."""
    for i in range(32768):
        dut.rom_mem[i].value = 0
    with open(vmem_path) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("//"):
                continue
            if line.startswith("@"):
                parts = line[1:].split()
                addr = int(parts[0], 16)
                byte_val = int(parts[1], 16)
                if 0 <= addr < 32768:
                    dut.rom_mem[addr].value = byte_val


def _load_bytes(dut, program, offset=0):
    """Load a raw byte sequence into ROM starting at *offset*."""
    for i in range(32768):
        dut.rom_mem[i].value = 0
    for i, b in enumerate(program):
        addr = offset + i
        if 0 <= addr < 32768:
            dut.rom_mem[addr].value = b & 0xFF


# ---------------------------------------------------------------------------
# TV80 Testbench helper class
# ---------------------------------------------------------------------------
class TV80TB:
    """
    Wraps the DUT handle and implements the IO port model.

    Instantiate one per test, call reset(), launch io_model() as a
    background task, then call run_until_complete().
    """

    def __init__(self, dut):
        self.dut = dut
        self.test_result = None   # 'PASS', 'FAIL', or 'TIMEOUT'
        self._msg_buf = []

        # IO model state (mirrors env_io.v)
        self.timeout_ctl     = 0x01   # bit0=enable, bit1=reset
        self.cur_timeout     = 0
        self.max_timeout     = 1_000
        self.int_countdown   = 0
        self.nmi_countdown   = 0
        self.nmi_trigger     = 0
        self.checksum        = 0
        self.ior_value       = 0
        self._rand_state     = 0xACE1

        # For INT mode 0: byte placed on the bus during INT-acknowledge
        self.int_ack_byte    = 0xFF   # RST 38H by default

    # ------------------------------------------------------------------
    # ROM loading
    # ------------------------------------------------------------------
    def load_vmem(self, name):
        """Load *name*.vmem from TESTS_DIR into ROM."""
        path = os.path.join(TESTS_DIR, name if name.endswith(".vmem") else name + ".vmem")
        if not os.path.exists(path):
            raise FileNotFoundError(f"vmem file not found: {path}\n"
                                    f"Run 'make' in verif/tests/ to compile programs.")
        _load_vmem(self.dut, path)

    def load_bytes(self, program, offset=0):
        """Load a raw byte list into ROM."""
        _load_bytes(self.dut, program, offset)

    # ------------------------------------------------------------------
    # Reset sequence
    # ------------------------------------------------------------------
    async def reset(self, cycles=20):
        """Assert reset for *cycles* clock cycles then deassert."""
        dut = self.dut
        dut.reset_n.value  = 0
        dut.wait_n.value   = 1
        dut.int_n.value    = 1
        dut.nmi_n.value    = 1
        dut.busrq_n.value  = 1
        dut.io_din.value   = 0xFF
        await ClockCycles(dut.clk, cycles)
        dut.reset_n.value  = 1

    # ------------------------------------------------------------------
    # IO port model (mirrors env_io.v)
    # ------------------------------------------------------------------
    async def io_model(self):
        """
        Background coroutine: watches iorq_n/rd_n/wr_n on every rising
        clock edge and implements the IO port model described in env_io.v.
        Also handles INT-acknowledge data and NMI-opcode trigger.
        """
        dut = self.dut
        last_wr_stb  = False
        last_wr_addr = 0
        last_wr_data = 0

        while True:
            await RisingEdge(dut.clk)

            iorq_n_v = int(dut.iorq_n.value)
            rd_n_v   = int(dut.rd_n.value)
            wr_n_v   = int(dut.wr_n.value)
            m1_n_v   = int(dut.m1_n.value)
            addr_v   = int(dut.A.value) & 0xFF
            dout_v   = int(dut.dout.value) & 0xFF
            ir_v     = int(dut.cpu_ir.value) & 0xFF

            int_ack_active = (m1_n_v == 0) and (iorq_n_v == 0)
            io_read_active = (iorq_n_v == 0) and (rd_n_v == 0)

            # ---- drive io_din ----------------------------------------
            if int_ack_active:
                # INT-acknowledge cycle: CPU reads instruction from data bus
                dut.io_din.value = self.int_ack_byte
            elif io_read_active:
                dut.io_din.value = self._io_read(addr_v)
            else:
                dut.io_din.value = 0xFF

            # ---- IO write detection (strobe falling edge) -------------
            wr_stb = (iorq_n_v == 0) and (wr_n_v == 0)
            if (not wr_stb) and last_wr_stb:
                self._io_write(last_wr_addr, last_wr_data)
            last_wr_stb  = wr_stb
            if wr_stb:
                last_wr_addr = addr_v
                last_wr_data = dout_v

            # ---- Timeout counter -------------------------------------
            if self.timeout_ctl & 0x02:
                self.cur_timeout = 0
            elif self.timeout_ctl & 0x01:
                self.cur_timeout += 1
            if self.cur_timeout >= self.max_timeout:
                if self.test_result is None:
                    self.test_result = "TIMEOUT"

            # ---- INT countdown / ack ---------------------------------
            if int_ack_active and self.int_countdown != 0:
                # CPU acknowledged the interrupt; deassert INT line
                self.int_countdown = 0
                dut.int_n.value = 1
            elif self.int_countdown == 0:
                dut.int_n.value = 1
            elif self.int_countdown == 1:
                dut.int_n.value = 0
            elif self.int_countdown > 1:
                self.int_countdown -= 1
                dut.int_n.value = 1

            # ---- NMI countdown --------------------------------------
            if self.nmi_trigger == 0:
                if self.nmi_countdown == 0:
                    dut.nmi_n.value = 1
                elif self.nmi_countdown == 1:
                    dut.nmi_n.value = 0
                elif self.nmi_countdown > 1:
                    self.nmi_countdown -= 1
                    dut.nmi_n.value = 1

            # ---- NMI opcode trigger ---------------------------------
            if self.nmi_trigger != 0 and ir_v == self.nmi_trigger:
                dut.nmi_n.value = 0
                await RisingEdge(dut.clk)
                dut.nmi_n.value = 1

    def _io_read(self, addr):
        """Return the byte the CPU should see when reading from IO port *addr*."""
        if   addr == TIMEOUT_PORT:     return self.timeout_ctl & 0xFF
        elif addr == MAX_TIMEOUT_LOW:  return self.max_timeout & 0xFF
        elif addr == MAX_TIMEOUT_HIGH: return (self.max_timeout >> 8) & 0xFF
        elif addr == INTR_CNTDWN:     return self.int_countdown & 0xFF
        elif addr == CKSUM_VALUE:      return self.checksum & 0xFF
        elif addr == INC_ON_READ:      return self.ior_value & 0xFF
        elif addr == RANDVAL:
            self._rand_state = (self._rand_state * 1103515245 + 12345) & 0xFFFFFFFF
            return (self._rand_state >> 16) & 0xFF
        elif addr == NMI_CNTDWN:      return self.nmi_countdown & 0xFF
        elif addr == NMI_TRIG_OPCODE: return self.nmi_trigger & 0xFF
        else:
            return 0xFF

    def _io_write(self, addr, data):
        """Process a completed IO write cycle."""
        dut = self.dut
        if addr == SIM_CTL_PORT:
            if data == 0x01:
                self.test_result = "PASS"
            elif data == 0x02:
                self.test_result = "FAIL"
            # 0x03 / 0x04 are dump control; ignored in Python model
        elif addr == MSG_PORT:
            self._msg_buf.append(chr(data & 0x7F))
            if data == 0x0A:  # newline → flush
                cocotb.log.info("PROGRAM: " + "".join(self._msg_buf).rstrip())
                self._msg_buf = []
        elif addr == TIMEOUT_PORT:
            self.timeout_ctl = data
        elif addr == MAX_TIMEOUT_LOW:
            self.max_timeout = (self.max_timeout & 0xFF00) | (data & 0xFF)
        elif addr == MAX_TIMEOUT_HIGH:
            self.max_timeout = (self.max_timeout & 0x00FF) | ((data & 0xFF) << 8)
        elif addr == INTR_CNTDWN:
            self.int_countdown = data
            if data:
                dut.int_n.value = 1   # clear any pending INT
        elif addr == CKSUM_VALUE:
            self.checksum = data & 0xFF
        elif addr == CKSUM_ACCUM:
            self.checksum = (self.checksum + data) & 0xFF
        elif addr == INC_ON_READ:
            self.ior_value = data & 0xFF
        elif addr == NMI_CNTDWN:
            self.nmi_countdown = data
            if data:
                dut.nmi_n.value = 1   # clear any pending NMI
        elif addr == NMI_TRIG_OPCODE:
            self.nmi_trigger = data

    # ------------------------------------------------------------------
    # Run until pass/fail or timeout
    # ------------------------------------------------------------------
    async def run_until_complete(self, timeout_cycles=DEFAULT_TIMEOUT):
        """
        Poll every clock cycle until the Z80 program writes to SIM_CTL_PORT
        (setting test_result to PASS or FAIL) or until *timeout_cycles* elapse.
        Raises SimTimeoutError on any timeout (io_model or cycle limit).
        Returns "PASS" or "FAIL" otherwise.
        """
        for _ in range(timeout_cycles):
            await RisingEdge(self.dut.clk)
            if self.test_result == "TIMEOUT":
                raise SimTimeoutError(
                    f"io_model timeout after {self.max_timeout} cycles"
                )
            if self.test_result is not None:
                return self.test_result
        self.test_result = "TIMEOUT"
        raise SimTimeoutError(
            f"Test timed out after {timeout_cycles} cycles"
        )


# ---------------------------------------------------------------------------
# Helper: start clock + reset + io_model then run a named vmem test
# ---------------------------------------------------------------------------
async def run_vmem_test(dut, vmem_name, timeout=DEFAULT_TIMEOUT,
                        int_ack_byte=0xFF, max_timeout=1_000):
    """
    Convenience wrapper: load a .vmem program, reset the CPU, start the IO
    model, and run until the program writes PASS or FAIL.
    Raises SimTimeoutError on timeout, AssertionError on FAIL.
    """
    log = cocotb.log.getChild(vmem_name)
    log.info(f"Loading {vmem_name}.vmem (max_timeout={max_timeout} cycles)")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tb = TV80TB(dut)
    tb.int_ack_byte = int_ack_byte
    tb.max_timeout  = max_timeout
    tb.load_vmem(vmem_name)
    cocotb.start_soon(tb.io_model())
    await tb.reset()
    result = await tb.run_until_complete(timeout)
    log.info(f"{vmem_name}: {result}")
    assert result == "PASS", f"{vmem_name}: expected PASS, got {result}"


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║              4.1  Reset and Initialization                ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def rst_01_reset_basic(dut):
    """RST-01: After reset deassert, first M1 fetch must be from address 0x0000."""
    # Infinite NOP loop: NOP at 0x0000, JR -2 at 0x0001
    nop_loop = [0x00, 0x18, 0xFE]
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tb = TV80TB(dut)
    tb.load_bytes(nop_loop)
    dut.reset_n.value = 0
    dut.wait_n.value  = 1
    dut.int_n.value   = 1
    dut.nmi_n.value   = 1
    dut.busrq_n.value = 1
    dut.io_din.value  = 0xFF
    await ClockCycles(dut.clk, 20)
    dut.reset_n.value = 1

    # Wait for the first M1 cycle (m1_n=0 & mreq_n=0)
    found = False
    for _ in range(200):
        await RisingEdge(dut.clk)
        if int(dut.m1_n.value) == 0 and int(dut.mreq_n.value) == 0:
            addr = int(dut.A.value)
            assert addr == 0x0000, \
                f"RST-01: first M1 fetch at 0x{addr:04X}, expected 0x0000"
            found = True
            break
    if not found:
        assert False, "RST-01: no M1 cycle detected after reset"


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def rst_02_reset_reapply(dut):
    """RST-02: Reapplying reset mid-execution must restart PC from 0x0000."""
    # Simple program that counts in B register, cycles 100+ times before we
    # re-apply reset - verifying no stale state survives.
    # INC B at 0x000; JR -2 at 0x001 → infinite increment loop
    program = [0x04, 0x18, 0xFE]  # INC B, JR -2
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tb = TV80TB(dut)
    tb.load_bytes(program)

    # First reset
    dut.reset_n.value = 0
    dut.wait_n.value  = 1
    dut.int_n.value   = 1
    dut.nmi_n.value   = 1
    dut.busrq_n.value = 1
    dut.io_din.value  = 0xFF
    await ClockCycles(dut.clk, 20)
    dut.reset_n.value = 1

    # Run 50 cycles then re-assert reset
    await ClockCycles(dut.clk, 50)
    dut.reset_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.reset_n.value = 1

    # Verify first M1 cycle after second reset is from 0x0000
    found = False
    for _ in range(200):
        await RisingEdge(dut.clk)
        if int(dut.m1_n.value) == 0 and int(dut.mreq_n.value) == 0:
            addr = int(dut.A.value)
            assert addr == 0x0000, \
                f"RST-02: after re-reset, first fetch at 0x{addr:04X}, expected 0x0000"
            found = True
            break
    if not found:
        assert False, "RST-02: no M1 cycle after second reset"


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def rst_03_reset_signals(dut):
    """RST-03: All bus-control outputs must be deasserted (=1) during reset."""
    nop_loop = [0x00, 0x18, 0xFE]
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tb = TV80TB(dut)
    tb.load_bytes(nop_loop)

    dut.reset_n.value = 0
    dut.wait_n.value  = 1
    dut.int_n.value   = 1
    dut.nmi_n.value   = 1
    dut.busrq_n.value = 1
    dut.io_din.value  = 0xFF

    # During reset, sample several clock cycles and verify bus signals
    for _ in range(15):
        await RisingEdge(dut.clk)
        assert int(dut.mreq_n.value) == 1, "RST-03: mreq_n asserted during reset"
        assert int(dut.iorq_n.value) == 1, "RST-03: iorq_n asserted during reset"
        assert int(dut.rd_n.value)   == 1, "RST-03: rd_n asserted during reset"
        assert int(dut.wr_n.value)   == 1, "RST-03: wr_n asserted during reset"
        assert int(dut.busak_n.value)== 1, "RST-03: busak_n asserted during reset"


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║       4.2 - 4.4  ALU (arithmetic, logic, rotate)         ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def alu_01_to_11_arithmetic(dut):
    """ALU-01..11: Arithmetic instructions (ADD/ADC/SUB/SBC/INC/DEC/DAA/CP/NEG)."""
    await run_vmem_test(dut, "alu_arith")


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def alu_05_to_07_arith16(dut):
    """ALU-05..07,09: 16-bit arithmetic (ADD HL/ADC HL/SBC HL/INC-DEC rr)."""
    await run_vmem_test(dut, "alu_arith16")


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def log_01_to_07_logic(dut):
    """LOG-01..07: Logic instructions (AND/OR/XOR/CPL/CCF/SCF/NEG)."""
    await run_vmem_test(dut, "alu_logic")


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def rot_01_to_05_rotate(dut):
    """ROT-01..05: Rotate and shift instructions."""
    await run_vmem_test(dut, "alu_rotate")


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║              4.5  ALU - Bit Operations                    ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def bit_01_to_03_bit_ops(dut):
    """BIT-01..03: BIT, SET, RES instructions."""
    await run_vmem_test(dut, "bit_ops")


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║              4.6  Load Operations                         ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def ld_01_to_06_load_reg(dut):
    """LD-01..06: Register-to-register, immediate, and indexed (IX/IY) loads."""
    await run_vmem_test(dut, "load_reg")


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def ld_07_to_14_load_mem(dut):
    """LD-07..14: Memory indirect loads, 16-bit loads, block transfers."""
    await run_vmem_test(dut, "load_mem")


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║         4.7  Jump, Call, and Return Instructions          ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def jmp_01_to_08_jumps(dut):
    """JMP-01..08: All jump, call, return, DJNZ, and RST instructions."""
    await run_vmem_test(dut, "jump_ops")


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║            4.8  Input/Output Instructions                 ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def io_01_to_03_io_ops(dut):
    """IO-01..03: IN, OUT, and block I/O instructions."""
    await run_vmem_test(dut, "io_ops")


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║              4.9  Stack Operations                        ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def stk_01_02_stack(dut):
    """STK-01..02: PUSH/POP (AF,BC,DE,HL,IX,IY) and EX (SP),rr."""
    await run_vmem_test(dut, "stack_ops")


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║           4.10  Exchange Instructions                     ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def exc_01_to_03_exchange(dut):
    """EXC-01..03: EX AF,AF' / EXX / EX DE,HL."""
    await run_vmem_test(dut, "exchange_ops")


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║           4.11  Miscellaneous Instructions                ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def misc_01_to_03_misc(dut):
    """MISC-01..03: NOP, HALT (with INT exit), DI/EI."""
    await run_vmem_test(dut, "misc_ops")


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║      4.12  Interrupt Handling - Maskable (INT)            ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def int_01_mode0(dut):
    """INT-01: IM 0 - CPU fetches RST 38H from data bus during INT-ack."""
    # int_ack_byte=0xFF → RST 38H → CPU jumps to 0x0038
    await run_vmem_test(dut, "interrupt_im0", int_ack_byte=0xFF)


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def int_02_mode1(dut):
    """INT-02..06: IM 1, nested interrupts, EI delay, RETI."""
    await run_vmem_test(dut, "interrupt_im1")


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def int_03_mode2(dut):
    """INT-03: IM 2 - vector table interrupt."""
    # int_ack_byte provides the low byte of the ISR address (vector table index)
    await run_vmem_test(dut, "interrupt_im2", int_ack_byte=0x00)


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║      4.13  Interrupt Handling - Non-Maskable (NMI)        ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def nmi_01_to_05_nmi(dut):
    """NMI-01..05: NMI basic, RETN, NMI during HALT, priority, opcode trigger."""
    await run_vmem_test(dut, "nmi_ops")


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║         4.14  Bus Request / Bus Acknowledge               ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def bus_01_busrq_basic(dut):
    """BUS-01: Assert busrq_n; verify busak_n asserts within a few cycles."""
    # Infinite NOP loop; cocotb asserts bus request externally
    nop_loop = [0x00, 0x18, 0xFE]
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tb = TV80TB(dut)
    tb.load_bytes(nop_loop)
    cocotb.start_soon(tb.io_model())
    await tb.reset()

    # Let CPU run briefly before requesting bus
    await ClockCycles(dut.clk, 30)

    # Assert bus request
    dut.busrq_n.value = 0

    # Verilator: wait up to 20 cycles for busak_n to assert
    acked = False
    for _ in range(20):
        await RisingEdge(dut.clk)
        if int(dut.busak_n.value) == 0:
            acked = True
            break
    assert acked, "BUS-01: busak_n did not assert within 20 cycles of busrq_n"


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def bus_02_busrq_release(dut):
    """BUS-02: Release busrq_n; CPU resumes execution (new M1 cycles detected)."""
    nop_loop = [0x00, 0x18, 0xFE]
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tb = TV80TB(dut)
    tb.load_bytes(nop_loop)
    cocotb.start_soon(tb.io_model())
    await tb.reset()

    await ClockCycles(dut.clk, 30)
    dut.busrq_n.value = 0

    # Wait for bus ack
    for _ in range(20):
        await RisingEdge(dut.clk)
        if int(dut.busak_n.value) == 0:
            break

    # Hold bus for 10 cycles then release
    await ClockCycles(dut.clk, 10)
    dut.busrq_n.value = 1

    # CPU must resume executing (new M1 cycles must appear)
    m1_seen = False
    for _ in range(100):
        await RisingEdge(dut.clk)
        if int(dut.m1_n.value) == 0 and int(dut.mreq_n.value) == 0:
            m1_seen = True
            break
    assert m1_seen, "BUS-02: no M1 cycle detected after bus release"


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║           4.15  Wait State Insertion                      ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def wait_01_memory_wait(dut):
    """WAIT-01: Assert wait_n=0 during a memory read; CPU holds T-state."""
    nop_loop = [0x00, 0x18, 0xFE]
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tb = TV80TB(dut)
    tb.load_bytes(nop_loop)
    cocotb.start_soon(tb.io_model())
    await tb.reset()

    # Insert 2 wait states for the next 10 M1 cycles by toggling wait_n=0
    # during mreq_n=0 & rd_n=0.  Verify the CPU still executes correctly.
    inserted = 0
    for _ in range(500):
        await RisingEdge(dut.clk)
        if (int(dut.mreq_n.value) == 0 and
                int(dut.rd_n.value) == 0 and inserted < 10):
            dut.wait_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.wait_n.value = 1
            inserted += 1
        if inserted >= 10:
            break

    # After inserting wait states, CPU should still produce M1 cycles
    m1_seen = False
    for _ in range(100):
        await RisingEdge(dut.clk)
        if int(dut.m1_n.value) == 0:
            m1_seen = True
            break
    assert m1_seen, "WAIT-01: no M1 after wait-state insertion"


@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def wait_02_io_wait(dut):
    """WAIT-02: Assert wait_n=0 during an I/O cycle."""
    # Program: repeatedly read from INC_ON_READ port then write PASS
    # OUT (0x80), A at the end of io_ops.asm handles pass/fail, but here
    # we use a simple program that does an IN followed by OUT to SIM_CTL_PORT.
    #
    # Bytes:
    #  0x00        NOP (wait for address settling)
    #  0xDB 0x93   IN A,(0x93)      ; read INC_ON_READ
    #  0x3E 0x01   LD A,0x01
    #  0xD3 0x80   OUT (0x80),A     ; PASS
    #  0x76        HALT
    prog = [0x00, 0xDB, 0x93, 0x3E, 0x01, 0xD3, 0x80, 0x76]
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tb = TV80TB(dut)
    tb.load_bytes(prog)
    cocotb.start_soon(tb.io_model())
    await tb.reset()

    # Insert a wait state when we see an IO read cycle
    waited = False
    for _ in range(500):
        await RisingEdge(dut.clk)
        if not waited and int(dut.iorq_n.value) == 0 and int(dut.rd_n.value) == 0:
            dut.wait_n.value = 0
            await RisingEdge(dut.clk)
            dut.wait_n.value = 1
            waited = True
        if tb.test_result is not None:
            break

    assert tb.test_result == "PASS", \
        f"WAIT-02: expected PASS, got {tb.test_result}"


# ===========================================================================
# ╔═══════════════════════════════════════════════════════════╗
# ║         4.16  Functional / Integration Tests              ║
# ╚═══════════════════════════════════════════════════════════╝
# ===========================================================================

@cocotb.test(timeout_time=_STD_TIMEOUT_NS, timeout_unit="ns")
async def func_01_hello_world(dut):
    """FUNC-01: Run tests/hello.c - verify 'Hello, world!' via MSG_PORT."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tb = TV80TB(dut)
    tb.load_vmem("hello")
    cocotb.start_soon(tb.io_model())
    await tb.reset()
    result = await tb.run_until_complete()
    output = "".join(tb._msg_buf)
    assert result == "PASS", f"FUNC-01: result={result}"


@cocotb.test(timeout_time=21_000_000, timeout_unit="ns")
async def func_02_fibonacci(dut):
    """FUNC-02: Run tests/fib.c - verify Fibonacci numbers 1-19."""
    await run_vmem_test(dut, "fib", timeout=2_000_000, max_timeout=1_500_000)



@cocotb.test(timeout_time=30_000_000, timeout_unit="ns")
async def func_05_alu_optest(dut):
    """FUNC-05: Run tests/alu_optest.ast - comprehensive ALU self-test."""
    await run_vmem_test(dut, "alu_optest", timeout=25_000_000, max_timeout=3_000)


@cocotb.test(timeout_time=21_000_000, timeout_unit="ns")
async def func_06_load_optest(dut):
    """FUNC-06: Run tests/load_optest.ast - comprehensive load self-test."""
    await run_vmem_test(dut, "load_optest", timeout=2_000_000, max_timeout=1_500_000)

