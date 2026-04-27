// TV80 Cocotb Testbench Top-Level Verilog Wrapper
//
// Instantiates tv80s with ROM (program), RAM (data), and an IO data input
// port driven by the cocotb Python test environment.  All tri-state signals
// are replaced with explicit muxes so the design is Verilator-compatible.
//
// Memory map:
//   0x0000 – 0x7FFF  ROM (A[15]=0)
//   0x8000 – 0xFFFF  RAM (A[15]=1)
//
// IO:
//   io_din   – 8-bit data driven by cocotb for IO reads and INT-ack cycles
//   io_cs    – asserted by this module when iorq_n & !rd_n (readable in Python)
//   int_ack  – asserted by this module when m1_n & iorq_n (INT acknowledge)
//
// cpu_ir is exposed so the cocotb NMI-opcode-trigger model can monitor the
// current instruction register without accessing deep hierarchy.

`timescale 1ns / 1ps

module tb_top (
    input        reset_n,
    input        wait_n,
    input        int_n,
    input        nmi_n,
    input        busrq_n,
    // IO port interface driven by cocotb
    input  [7:0] io_din,
    // CPU outputs
    output       m1_n,
    output       mreq_n,
    output       iorq_n,
    output       rd_n,
    output       wr_n,
    output       rfsh_n,
    output       halt_n,
    output       busak_n,
    output [15:0] A,
    output [7:0]  dout,
    // Derived status signals for cocotb monitoring
    output       io_cs,
    output       int_ack,
    output [7:0] cpu_ir
);

    // -----------------------------------------------------------------------
    // Clock generation (10 ns period, free-running)
    // -----------------------------------------------------------------------
    reg clk;
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // ROM (program space, A[15]=0, read-only from CPU side)
    // Exposed as public so cocotb can write program bytes before reset.
    // -----------------------------------------------------------------------
    reg [7:0] rom_mem [0:32767] /* verilator public */;

    // -----------------------------------------------------------------------
    // RAM (data space, A[15]=1, read/write)
    // -----------------------------------------------------------------------
    reg [7:0] ram_mem [0:32767] /* verilator public */;

    // -----------------------------------------------------------------------
    // Address decode
    // -----------------------------------------------------------------------
    wire rom_rd_cs = !mreq_n & !rd_n & !A[15];
    wire ram_rd_cs = !mreq_n & !rd_n &  A[15];
    wire ram_wr_cs = !mreq_n & !wr_n &  A[15];

    // io_cs: asserted during IO read cycles (iorq_n=0, rd_n=0)
    assign io_cs   = !iorq_n & !rd_n;

    // int_ack: asserted during INT-acknowledge cycles (m1_n=0, iorq_n=0)
    // and only when an interrupt request is actually pending. The Chisel
    // variant can transiently present M1/IORQ during normal startup fetch
    // sequencing, so avoid sourcing io_din unless INT is active.
    assign int_ack = !m1_n & !iorq_n & !int_n;

    // -----------------------------------------------------------------------
    // Data bus mux (replaces tri-state bus)
    // Priority: IO/INT-ack > RAM > ROM
    // cocotb drives io_din for both IO reads and INT-ack data (e.g. RST 38H)
    // -----------------------------------------------------------------------
    wire [7:0] rom_data = rom_mem[A[14:0]];
    wire [7:0] ram_data = ram_mem[A[14:0]];
    wire [7:0] di = (io_cs | int_ack) ? io_din
                  : (A[15]            ? ram_data
                                      : rom_data);

    // -----------------------------------------------------------------------
    // RAM write port
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (ram_wr_cs)
            ram_mem[A[14:0]] <= dout;
    end

    // -----------------------------------------------------------------------
    // DUT: tv80s (synchronous Z80 wrapper)
    // -----------------------------------------------------------------------
    tv80s #(
        .Mode   (0),   // Z80 mode
        .T2Write(1),   // wr_n active in T2
        .IOWait (1)    // Standard I/O cycle with wait state
    ) tv80s_inst (
        .m1_n   (m1_n),
        .mreq_n (mreq_n),
        .iorq_n (iorq_n),
        .rd_n   (rd_n),
        .wr_n   (wr_n),
        .rfsh_n (rfsh_n),
        .halt_n (halt_n),
        .busak_n(busak_n),
        .A      (A),
        .dout   (dout),
        .reset_n(reset_n),
        .clk    (clk),
        .wait_n (wait_n),
        .int_n  (int_n),
        .nmi_n  (nmi_n),
        .busrq_n(busrq_n),
        .di     (di)
    );

    // -----------------------------------------------------------------------
    // Expose instruction register for NMI opcode-trigger monitoring
    // -----------------------------------------------------------------------
    assign cpu_ir = tv80s_inst.i_tv80_core.IR;

    // -----------------------------------------------------------------------
    // Memory initialisation – zeroed so unused ROM locations are NOPs (0x00)
    // -----------------------------------------------------------------------
    integer init_i;
    initial begin
        for (init_i = 0; init_i < 32768; init_i = init_i + 1) begin
            rom_mem[init_i] = 8'h00;
            ram_mem[init_i] = 8'h00;
        end
    end

    // -----------------------------------------------------------------------
    // Waveform dump (enabled by WAVES=1 compile flag)
    // -----------------------------------------------------------------------
`ifdef TV80_WAVES
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end
`endif

endmodule
