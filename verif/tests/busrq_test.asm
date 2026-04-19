; busrq_test.asm – BUS-01, BUS-02 support program
;
; The actual bus-request signal manipulation (busrq_n / busak_n) is done
; by the cocotb Python test functions (bus_01_busrq_basic and
; bus_02_busrq_release).  This program simply runs an infinite loop so
; the CPU is actively executing during the bus-request sequence.

    .module busrq_test

_sim_ctl_port = 0x80

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100
main:
    ld  sp, #0xFFFF
    ld  bc, #0x0000         ; use BC as a cycle counter
loop:
    inc bc                  ; increment on every pass
    jp  loop                ; infinite loop
