`timescale 1ns / 1ps

// Compatibility wrapper that exposes the legacy tv80s module/port shape
// while instantiating Chisel-generated Tv80s.
module tv80s #(
    parameter integer Mode    = 0,
    parameter integer T2Write = 1,
    parameter integer IOWait  = 1
) (
    output        m1_n,
    output        mreq_n,
    output        iorq_n,
    output        rd_n,
    output        wr_n,
    output        rfsh_n,
    output        halt_n,
    output        busak_n,
    output [15:0] A,
    output [7:0]  dout,
    input         reset_n,
    input         clk,
    input         wait_n,
    input         int_n,
    input         nmi_n,
    input         busrq_n,
    input  [7:0]  di
);

    // Parameters are intentionally ignored. The generated Chisel top encodes
    // a fixed behavior equivalent to the default legacy testbench settings.
    Tv80s dut (
        .clock      (clk),
        .reset      (!reset_n),
        .io_reset_n (reset_n),
        .io_wait_n  (wait_n),
        .io_int_n   (int_n),
        .io_nmi_n   (nmi_n),
        .io_busrq_n (busrq_n),
        .io_m1_n    (m1_n),
        .io_mreq_n  (mreq_n),
        .io_iorq_n  (iorq_n),
        .io_rd_n    (rd_n),
        .io_wr_n    (wr_n),
        .io_rfsh_n  (rfsh_n),
        .io_halt_n  (halt_n),
        .io_busak_n (busak_n),
        .io_A       (A),
        .io_di      (di),
        .io_dout    (dout)
    );

    wire [7:0] cpu_ir_probe;

    // Compatibility probe so tb_top can keep using
    // tv80s_inst.i_tv80_core.IR regardless of RTL variant.
    tv80_core_ir_compat i_tv80_core (
        .src(dut.core.IR),
        .IR (cpu_ir_probe)
    );

endmodule

module tv80_core_ir_compat (
    input  [7:0] src,
    output [7:0] IR
);
    assign IR = src;
endmodule
