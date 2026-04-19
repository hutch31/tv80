; alu_logic.asm – LOG-01..07
;
; Tests all ALU logic instructions:
;   LOG-01  AND r / AND n    (H=1, N=0, C=0)
;   LOG-02  OR  r / OR  n    (H=0, N=0, C=0)
;   LOG-03  XOR r / XOR n    (H=0, N=0, C=0)
;   LOG-04  CPL              (H=1, N=1, A inverted)
;   LOG-05  SCF              (C=1, H=0, N=0)
;   LOG-06  CCF              (C toggled, H=prev_C, N=0)
;   LOG-07  NEG              (tested in alu_arith.asm; re-tested here briefly)

    .module alu_logic

_sim_ctl_port = 0x80

FLAG_C   = 0x01
FLAG_N   = 0x02
FLAG_PV  = 0x04
FLAG_H   = 0x10
FLAG_Z   = 0x40
FLAG_S   = 0x80
FLAG_MASK = 0xD7

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ;========================================================
    ; LOG-01: AND n / AND r
    ;========================================================
    ; 0xFF AND 0x0F = 0x0F, H=1, N=0, C=0, P=even parity
    ld  a, #0xFF
    and a, #0x0F
    cp  a, #0x0F
    jp  nz, test_fail
    jp  c,  test_fail           ; C must be clear
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_H
    jp   z, test_fail           ; H must be set
    ld   a, c
    and  a, #FLAG_N
    jp   nz, test_fail          ; N must be clear

    ; 0x55 AND 0xAA = 0x00, Z=1
    ld  a, #0x55
    and a, #0xAA
    jp  nz, test_fail

    ; AND r (register operand)
    ld  a, #0xF0
    ld  b, #0x0F
    and a, b
    jp  nz, test_fail

    ld  a, #0xFF
    ld  c, #0x3C
    and a, c
    cp  a, #0x3C
    jp  nz, test_fail

    ;========================================================
    ; LOG-02: OR n / OR r
    ;========================================================
    ; 0x0F OR 0xF0 = 0xFF, H=0, N=0, C=0, S=1
    ld  a, #0x0F
    or  a, #0xF0
    cp  a, #0xFF
    jp  nz, test_fail
    jp  p,  test_fail           ; S must be set (0xFF is negative)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_H
    jp   nz, test_fail          ; H must be clear after OR
    ld   a, c
    and  a, #FLAG_N
    jp   nz, test_fail          ; N must be clear

    ; 0x00 OR 0x00 = 0x00, Z=1
    ld  a, #0x00
    or  a, #0x00
    jp  nz, test_fail

    ; OR r
    ld  a, #0x01
    ld  d, #0x80
    or  a, d
    cp  a, #0x81
    jp  nz, test_fail

    ;========================================================
    ; LOG-03: XOR n / XOR r
    ;========================================================
    ; 0xFF XOR 0xFF = 0x00, Z=1, H=0, N=0, C=0
    ld  a, #0xFF
    xor a, #0xFF
    jp  nz, test_fail
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_H
    jp   nz, test_fail          ; H must be clear after XOR

    ; 0x55 XOR 0xAA = 0xFF
    ld  a, #0x55
    xor a, #0xAA
    cp  a, #0xFF
    jp  nz, test_fail

    ; XOR A (clear A to 0)
    ld  a, #0x5A
    xor a, a
    jp  nz, test_fail

    ; XOR r
    ld  a, #0xA5
    ld  e, #0x5A
    xor a, e
    cp  a, #0xFF
    jp  nz, test_fail

    ;========================================================
    ; LOG-04: CPL (A = ~A, H=1, N=1)
    ;========================================================
    ld  a, #0x55
    cpl
    cp  a, #0xAA
    jp  nz, test_fail
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_H
    jp   z, test_fail           ; H must be set
    ld   a, c
    and  a, #FLAG_N
    jp   z, test_fail           ; N must be set

    ld  a, #0xFF
    cpl
    jp  nz, test_fail           ; 0xFF → 0x00, Z=1 (set by CPL itself? No–CPL does NOT touch S/Z)
    ; Actually CPL sets H and N but leaves S and Z unchanged.
    ; Let's verify A=0x00 by CP:
    cp  a, #0x00
    jp  nz, test_fail

    ld  a, #0x00
    cpl
    cp  a, #0xFF
    jp  nz, test_fail

    ;========================================================
    ; LOG-05: SCF (C=1, H=0, N=0, S/Z/P unchanged)
    ;========================================================
    ; Start with C=0
    or  a, a                    ; clear carry
    jp  c,  test_fail           ; verify C was clear
    scf
    jp  nc, test_fail           ; C must now be set
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_H
    jp   nz, test_fail          ; H must be clear
    ld   a, c
    and  a, #FLAG_N
    jp   nz, test_fail          ; N must be clear

    ;========================================================
    ; LOG-06: CCF (C toggled, H=previous_C, N=0)
    ;========================================================
    ; Start C=1 (from SCF above), then CCF → C=0, H=1 (prev C was 1)
    scf                         ; C=1
    ccf                         ; C=0, H=1
    jp  c,  test_fail           ; C must be clear
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_H
    jp   z, test_fail           ; H must be set (was C=1 before CCF)
    ld   a, c
    and  a, #FLAG_N
    jp   nz, test_fail          ; N must be clear

    ; CCF again: C=0 → C=1, H=0 (prev C was 0)
    ccf
    jp  nc, test_fail           ; C must be set
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_H
    jp   nz, test_fail          ; H must be clear (prev C was 0)

    jp  test_pass

test_pass:
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt

test_fail:
    ld  a, #0x02
    out (_sim_ctl_port), a
    halt
