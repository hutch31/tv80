; exchange_ops.asm – EXC-01..03
;
;   EXC-01  EX AF,AF'  (swap A and F with shadow registers A' and F')
;   EXC-02  EXX        (swap BC,DE,HL with BC',DE',HL')
;   EXC-03  EX DE,HL   (swap DE and HL)

    .module exchange_ops

_sim_ctl_port = 0x80

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ;========================================================
    ; EXC-03: EX DE,HL (simplest – test first)
    ;========================================================
    ld  de, #0x1234
    ld  hl, #0xABCD
    ex  de, hl              ; DE ↔ HL: DE=0xABCD, HL=0x1234
    ld  a, d
    cp  a, #0xAB
    jp  nz, test_fail
    ld  a, e
    cp  a, #0xCD
    jp  nz, test_fail
    ld  a, h
    cp  a, #0x12
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x34
    jp  nz, test_fail

    ; EX DE,HL twice = identity
    ex  de, hl
    ld  a, d
    cp  a, #0x12
    jp  nz, test_fail
    ld  a, h
    cp  a, #0xAB
    jp  nz, test_fail

    ;========================================================
    ; EXC-01: EX AF,AF'
    ;========================================================
    ; Set A=0x42 and specific flags, then swap to shadow
    ld  a, #0x42
    scf                     ; C=1
    ex  af, af'             ; swap A/F with shadow
    ; Now main A/F are undefined (from shadow), shadow has A=0x42, C=1
    ; Load new values
    ld  a, #0x00
    or  a, a                ; A=0x00, Z=1, C=0
    ; Swap back
    ex  af, af'             ; restore: A=0x42, C=1
    jp  nc, test_fail       ; C must be restored (check before cp clobbers it)
    cp  a, #0x42
    jp  nz, test_fail

    ; Double swap (should be identity again)
    ld  a, #0xAA
    xor a, a                ; A=0x00, Z=1
    ex  af, af'             ; shadow has A=0x00, Z=1
    ld  a, #0x55
    scf                     ; main: A=0x55, C=1
    ex  af, af'             ; shadow↔main: A=0x00, Z=1, C=0
    jp  nz, test_fail       ; Z must be set from original XOR

    ;========================================================
    ; EXC-02: EXX
    ;========================================================
    ; Load distinct values into all main registers
    ld  bc, #0x1111
    ld  de, #0x2222
    ld  hl, #0x3333
    exx                     ; swap with shadow (shadow values are indeterminate)
    ; Load different values into main registers
    ld  bc, #0xAAAA
    ld  de, #0xBBBB
    ld  hl, #0xCCCC
    exx                     ; swap back: main = 0x1111/2222/3333, shadow = AAAA/BBBB/CCCC
    ld  a, b
    cp  a, #0x11
    jp  nz, test_fail
    ld  a, c
    cp  a, #0x11
    jp  nz, test_fail
    ld  a, d
    cp  a, #0x22
    jp  nz, test_fail
    ld  a, e
    cp  a, #0x22
    jp  nz, test_fail
    ld  a, h
    cp  a, #0x33
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x33
    jp  nz, test_fail

    ; EXX again: back to AAAA/BBBB/CCCC
    exx
    ld  a, b
    cp  a, #0xAA
    jp  nz, test_fail
    ld  a, d
    cp  a, #0xBB
    jp  nz, test_fail
    ld  a, h
    cp  a, #0xCC
    jp  nz, test_fail

    ; Verify EXX does NOT affect AF
    exx                     ; restore main regs
    ld  a, #0x55
    scf
    exx                     ; swap BC/DE/HL only
    jp  nc, test_fail       ; carry must still be set
    cp  a, #0x55
    jp  nz, test_fail       ; A must still be 0x55

    jp  test_pass

test_pass:
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt

test_fail:
    ld  a, #0x02
    out (_sim_ctl_port), a
    halt
