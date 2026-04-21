; bit_ops.asm – BIT-01..03
;
;   BIT-01  BIT b,r  (test bit b of register r, sets Z=~bit, H=1, N=0)
;   BIT-02  SET b,r  (set bit b of register r)
;   BIT-03  RES b,r  (reset bit b of register r)
;
; All operations use the CB-prefix encoding:
;   BIT b,r  =  CB (0x40 + b*8 + r)
;   RES b,r  =  CB (0x80 + b*8 + r)
;   SET b,r  =  CB (0xC0 + b*8 + r)
; Register encoding: B=0 C=1 D=2 E=3 H=4 L=5 (HL)=6 A=7

    .module bit_ops

_sim_ctl_port = 0x80
FLAG_Z   = 0x40
FLAG_H   = 0x10
FLAG_N   = 0x02

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ;========================================================
    ; BIT-01: BIT b,r
    ;========================================================
    ; BIT 0,A: A=0x01, bit0=1 → Z=0, H=1, N=0
    ld  a, #0x01
    .db 0xCB, 0x47          ; BIT 0,A
    jp  z,  test_fail       ; Z must be clear (bit IS set)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_H
    jp   z, test_fail       ; H must be set
    ld   a, c
    and  a, #FLAG_N
    jp   nz, test_fail      ; N must be clear

    ; BIT 0,A: A=0xFE, bit0=0 → Z=1
    ld  a, #0xFE
    .db 0xCB, 0x47          ; BIT 0,A
    jp  nz, test_fail       ; Z must be set (bit NOT set)

    ; BIT 7,A: A=0x80, bit7=1 → Z=0, S=1 (bit 7)
    ld  a, #0x80
    .db 0xCB, 0x7F          ; BIT 7,A
    jp  z,  test_fail       ; Z must be clear
    jp  p,  test_fail       ; S must be set (bit7 tested)

    ; BIT 7,A: A=0x7F, bit7=0 → Z=1
    ld  a, #0x7F
    .db 0xCB, 0x7F          ; BIT 7,A
    jp  nz, test_fail

    ; BIT 4,B: B=0x10, bit4=1 → Z=0
    ld  b, #0x10
    .db 0xCB, 0x60          ; BIT 4,B
    jp  z,  test_fail

    ; BIT 4,B: B=0xEF, bit4=0 → Z=1
    ld  b, #0xEF
    .db 0xCB, 0x60          ; BIT 4,B
    jp  nz, test_fail

    ; BIT 3,C: C=0x08 → Z=0
    ld  c, #0x08
    .db 0xCB, 0x59          ; BIT 3,C
    jp  z,  test_fail

    ; BIT 3,C: C=0xF7 → Z=1
    ld  c, #0xF7
    .db 0xCB, 0x59          ; BIT 3,C
    jp  nz, test_fail

    ; BIT 1,(HL): (HL)=0x02, bit1=1 → Z=0
    ld  hl, #0x8000
    ld  (hl), #0x02
    .db 0xCB, 0x4E          ; BIT 1,(HL)
    jp  z,  test_fail

    ;========================================================
    ; BIT-02: SET b,r
    ;========================================================
    ; SET 0,A: A=0x00 → 0x01
    ld  a, #0x00
    .db 0xCB, 0xC7          ; SET 0,A
    cp  a, #0x01
    jp  nz, test_fail

    ; SET 7,A: A=0x00 → 0x80
    ld  a, #0x00
    .db 0xCB, 0xFF          ; SET 7,A
    cp  a, #0x80
    jp  nz, test_fail

    ; SET 4,B: B=0x00 → 0x10
    ld  b, #0x00
    .db 0xCB, 0xE0          ; SET 4,B
    ld  a, b
    cp  a, #0x10
    jp  nz, test_fail

    ; SET 2,C: C=0x00 → 0x04
    ld  c, #0x00
    .db 0xCB, 0xD1          ; SET 2,C
    ld  a, c
    cp  a, #0x04
    jp  nz, test_fail

    ; SET 5,D: D=0xC0 → 0xE0 (set bit 5 of 1100_0000)
    ld  d, #0xC0
    .db 0xCB, 0xEA          ; SET 5,D
    ld  a, d
    cp  a, #0xE0
    jp  nz, test_fail

    ; SET all bits in E one by one → 0xFF
    ld  e, #0x00
    .db 0xCB, 0xC3          ; SET 0,E
    .db 0xCB, 0xCB          ; SET 1,E
    .db 0xCB, 0xD3          ; SET 2,E
    .db 0xCB, 0xDB          ; SET 3,E
    .db 0xCB, 0xE3          ; SET 4,E
    .db 0xCB, 0xEB          ; SET 5,E
    .db 0xCB, 0xF3          ; SET 6,E
    .db 0xCB, 0xFB          ; SET 7,E
    ld  a, e
    cp  a, #0xFF
    jp  nz, test_fail

    ; SET 0,(HL): (HL)=0x00 → 0x01
    ld  hl, #0x8000
    ld  (hl), #0x00
    .db 0xCB, 0xC6          ; SET 0,(HL)
    ld  a, (hl)
    cp  a, #0x01
    jp  nz, test_fail

    ;========================================================
    ; BIT-03: RES b,r
    ;========================================================
    ; RES 0,A: A=0xFF → 0xFE
    ld  a, #0xFF
    .db 0xCB, 0x87          ; RES 0,A
    cp  a, #0xFE
    jp  nz, test_fail

    ; RES 7,A: A=0xFF → 0x7F
    ld  a, #0xFF
    .db 0xCB, 0xBF          ; RES 7,A
    cp  a, #0x7F
    jp  nz, test_fail

    ; RES 4,B: B=0xFF → 0xEF
    ld  b, #0xFF
    .db 0xCB, 0xA0          ; RES 4,B
    ld  a, b
    cp  a, #0xEF
    jp  nz, test_fail

    ; RES all bits in L → 0x00
    ld  l, #0xFF
    .db 0xCB, 0x85          ; RES 0,L
    .db 0xCB, 0x8D          ; RES 1,L
    .db 0xCB, 0x95          ; RES 2,L
    .db 0xCB, 0x9D          ; RES 3,L
    .db 0xCB, 0xA5          ; RES 4,L
    .db 0xCB, 0xAD          ; RES 5,L
    .db 0xCB, 0xB5          ; RES 6,L
    .db 0xCB, 0xBD          ; RES 7,L
    ld  a, l
    jp  nz, test_fail       ; L must be 0x00

    ; RES 3,(HL): (HL)=0xFF → 0xF7
    ld  hl, #0x8000
    ld  (hl), #0xFF
    .db 0xCB, 0x9E          ; RES 3,(HL)
    ld  a, (hl)
    cp  a, #0xF7
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
