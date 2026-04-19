; wait_test.asm – WAIT-01, WAIT-02 support program
;
; The actual wait-state insertion (wait_n toggling) is driven by the
; cocotb Python test functions (wait_01_memory_wait, wait_02_io_wait).
; This program exercises memory reads/writes and one IO read so cocotb
; can insert wait states during those cycles.

    .module wait_test

_sim_ctl_port = 0x80
_inc_on_read  = 0x93

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ; Memory read/write cycles for WAIT-01
    ld  hl, #0x8000
    ld  (hl), #0xAA
    ld  a, (hl)
    cp  a, #0xAA
    jp  nz, test_fail

    ld  (hl), #0x55
    ld  a, (hl)
    cp  a, #0x55
    jp  nz, test_fail

    ; IO read for WAIT-02
    ld  a, #0xBB
    out (_inc_on_read), a   ; set INC_ON_READ = 0xBB
    in  a, (_inc_on_read)   ; read it back
    cp  a, #0xBB
    jp  nz, test_fail

    jp  test_pass

test_pass:
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt

test_fail:
    ld  a, #0x02
    out (_sim_ctl_port), a
    halt
