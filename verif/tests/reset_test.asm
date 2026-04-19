; reset_test.asm – RST-01..03 support program
;
; Minimal program used by the cocotb reset tests (RST-01..03).
; It simply writes PASS (0x01) to SIM_CTL_PORT.
; The actual signal-level checks (m1_n, A bus, bus-control deasserted
; during reset) are performed by the cocotb Python test functions.

    .module reset_test

_sim_ctl_port   = 0x80

    .area PROGMEM (ABS)
    .org 0x0000

    jp  main

    .org 0x0100

main:
    ld  sp, #0xFFFF
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt
