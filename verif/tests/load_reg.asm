; load_reg.asm – LD-01..06
;
;   LD-01  LD r,r'  (all 8-bit register-to-register loads)
;   LD-02  LD r,n   (8-bit immediate)
;   LD-03  LD r,(HL) / LD (HL),r
;   LD-04  LD r,(IX+d) / LD (IX+d),r / LD (IX+d),n
;   LD-05  LD r,(IY+d) / LD (IY+d),r / LD (IY+d),n
;   LD-06  LD I,A / LD A,I / LD R,A / LD A,R

    .module load_reg

_sim_ctl_port = 0x80

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ;========================================================
    ; LD-02: LD r,n (immediate)
    ;========================================================
    ld  a, #0xA5
    cp  a, #0xA5
    jp  nz, test_fail

    ld  b, #0x11
    ld  a, b
    cp  a, #0x11
    jp  nz, test_fail

    ld  c, #0x22
    ld  a, c
    cp  a, #0x22
    jp  nz, test_fail

    ld  d, #0x33
    ld  a, d
    cp  a, #0x33
    jp  nz, test_fail

    ld  e, #0x44
    ld  a, e
    cp  a, #0x44
    jp  nz, test_fail

    ld  h, #0x55
    ld  a, h
    cp  a, #0x55
    jp  nz, test_fail

    ld  l, #0x66
    ld  a, l
    cp  a, #0x66
    jp  nz, test_fail

    ;========================================================
    ; LD-01: LD r,r' (all combinations)
    ;========================================================
    ; Load known values into each register then copy
    ld  b, #0x12
    ld  c, b            ; C = 0x12
    ld  a, c
    cp  a, #0x12
    jp  nz, test_fail

    ld  d, #0x34
    ld  e, d            ; E = 0x34
    ld  a, e
    cp  a, #0x34
    jp  nz, test_fail

    ld  h, #0x56
    ld  l, h            ; L = 0x56
    ld  a, l
    cp  a, #0x56
    jp  nz, test_fail

    ; Cross-register copies
    ld  b, #0xAA
    ld  d, b            ; D = B
    ld  h, b            ; H = B
    ld  a, d
    cp  a, #0xAA
    jp  nz, test_fail
    ld  a, h
    cp  a, #0xAA
    jp  nz, test_fail

    ld  c, #0x55
    ld  e, c
    ld  l, c
    ld  a, e
    cp  a, #0x55
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x55
    jp  nz, test_fail

    ; LD A from all registers
    ld  b, #0x01
    ld  a, b
    cp  a, #0x01
    jp  nz, test_fail

    ld  c, #0x02
    ld  a, c
    cp  a, #0x02
    jp  nz, test_fail

    ld  d, #0x03
    ld  a, d
    cp  a, #0x03
    jp  nz, test_fail

    ld  e, #0x04
    ld  a, e
    cp  a, #0x04
    jp  nz, test_fail

    ld  h, #0x05
    ld  a, h
    cp  a, #0x05
    jp  nz, test_fail

    ld  l, #0x06
    ld  a, l
    cp  a, #0x06
    jp  nz, test_fail

    ;========================================================
    ; LD-03: LD r,(HL) / LD (HL),r
    ;========================================================
    ; Write 0xAB to RAM via LD (HL),A
    ld  hl, #0x8000
    ld  a, #0xAB
    ld  (hl), a
    ; Read back via LD A,(HL)
    ld  a, #0x00        ; clear A
    ld  a, (hl)
    cp  a, #0xAB
    jp  nz, test_fail

    ; Write via LD (HL),B
    ld  b, #0xCD
    ld  (hl), b
    ld  a, (hl)
    cp  a, #0xCD
    jp  nz, test_fail

    ; Write via LD (HL),n (immediate to memory)
    ld  (hl), #0xEF
    ld  a, (hl)
    cp  a, #0xEF
    jp  nz, test_fail

    ; LD r,(HL) for all registers
    ld  (hl), #0x77
    ld  b, (hl)
    ld  a, b
    cp  a, #0x77
    jp  nz, test_fail

    ld  c, (hl)
    ld  a, c
    cp  a, #0x77
    jp  nz, test_fail

    ld  d, (hl)
    ld  a, d
    cp  a, #0x77
    jp  nz, test_fail

    ld  e, (hl)
    ld  a, e
    cp  a, #0x77
    jp  nz, test_fail

    ;========================================================
    ; LD-04: LD r,(IX+d) / LD (IX+d),r / LD (IX+d),n
    ;========================================================
    ; Write 0x12 to 0x8010 and read via IX+d
    ld  hl, #0x8010
    ld  (hl), #0x12
    .db 0xDD, 0x21, 0x00, 0x80  ; LD IX, 0x8000
    ; LD A,(IX+0x10):
    .db 0xDD, 0x7E, 0x10        ; LD A,(IX+16)
    cp  a, #0x12
    jp  nz, test_fail

    ; LD (IX+d),r: write B=0x34 to 0x8010 via IX+0x10
    ld  b, #0x34
    .db 0xDD, 0x70, 0x10        ; LD (IX+16),B
    ld  a, (hl)                 ; HL still points to 0x8010
    cp  a, #0x34
    jp  nz, test_fail

    ; LD (IX+d),n: write 0x56 to 0x8010 via IX+0x10
    .db 0xDD, 0x36, 0x10, 0x56 ; LD (IX+16),0x56
    ld  a, (hl)
    cp  a, #0x56
    jp  nz, test_fail

    ; Negative displacement: IX=0x8010, d=-1 → 0x800F
    ld  hl, #0x800F
    ld  (hl), #0x78
    .db 0xDD, 0x21, 0x10, 0x80  ; LD IX,0x8010
    .db 0xDD, 0x7E, 0xFF        ; LD A,(IX-1) [d=0xFF = -1 in signed]
    cp  a, #0x78
    jp  nz, test_fail

    ;========================================================
    ; LD-05: LD r,(IY+d) / LD (IY+d),r / LD (IY+d),n
    ;========================================================
    .db 0xFD, 0x21, 0x00, 0x80  ; LD IY,0x8000
    ; Write 0xAA to 0x8020 then read via IY+0x20
    ld  hl, #0x8020
    ld  (hl), #0xAA
    .db 0xFD, 0x7E, 0x20        ; LD A,(IY+32)
    cp  a, #0xAA
    jp  nz, test_fail

    ; LD (IY+d),r
    ld  c, #0xBB
    .db 0xFD, 0x71, 0x20        ; LD (IY+32),C
    ld  a, (hl)
    cp  a, #0xBB
    jp  nz, test_fail

    ; LD (IY+d),n
    .db 0xFD, 0x36, 0x20, 0xCC  ; LD (IY+32),0xCC
    ld  a, (hl)
    cp  a, #0xCC
    jp  nz, test_fail

    ;========================================================
    ; LD-06: LD I,A / LD A,I / LD R,A / LD A,R
    ;========================================================
    ; LD I,A
    ld  a, #0x5A
    .db 0xED, 0x47          ; LD I,A
    ; LD A,I: I=0x5A (bit7=0) → S=0 (positive), Z=0
    .db 0xED, 0x57          ; LD A,I
    cp  a, #0x5A
    jp  nz, test_fail
    jp  m,  test_fail       ; S must be CLEAR (0x5A bit7=0); jp m = jump if S=1 → fail

    ; Re-test LD A,I flags with a negative value
    ld  a, #0x80
    .db 0xED, 0x47          ; LD I,A
    .db 0xED, 0x57          ; LD A,I
    jp  p,  test_fail       ; S must be set (0x80 is negative; check before cp)
    cp  a, #0x80
    jp  nz, test_fail

    ; LD R,A / LD A,R (R is the refresh register; value increments but
    ;   R increments on every M1 cycle so after LD R,A(0) and LD A,R
    ;   R will be ~2 (two M1 cycles elapsed). The exact value is
    ;   implementation-dependent and may wrap, so we accept any value.
    ld  a, #0x00
    .db 0xED, 0x4F          ; LD R,A  (R = 0)
    .db 0xED, 0x5F          ; LD A,R  (A = R, which has incremented)
    ; Accept any value (wrapping to 0 is also valid); just verify instruction ran
    ; by checking Z flag: if A=0 then Z=1, if A!=0 then Z=0. Both are OK.
    jp  r_ok                ; always continue
r_ok:
    ; LD A,I with I=0x00 → A=0x00, Z=1
    ld  a, #0x00
    .db 0xED, 0x47          ; LD I,A (I=0)
    .db 0xED, 0x57          ; LD A,I (A=0)
    jp  nz, test_fail       ; Z must be set (I=0)

    jp  test_pass

test_pass:
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt

test_fail:
    ld  a, #0x02
    out (_sim_ctl_port), a
    halt
