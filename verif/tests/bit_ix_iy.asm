; bit_ix_iy.asm – BIT-04
;
; Tests BIT/SET/RES instructions on IX-indexed and IY-indexed memory
; using the DDCB / FDCB 4-byte prefix encoding.
;
; These instructions exercise:
;   - Pre_XY_F_M flag-mode tracking register in Tv80Core
;   - mcycle[5] prefix-detection path (Prefix==CB while in DD/FD mode)
;   - mcycle[6] IR/ISet latch path (ISet==CB at the 7th machine cycle)
;
; Encoding reference:
;   BIT b,(IX+d) = DD CB d (0x40 + b*8 + 6)
;   SET b,(IX+d) = DD CB d (0xC0 + b*8 + 6)
;   RES b,(IX+d) = DD CB d (0x80 + b*8 + 6)
;   Replace DD with FD for IY variants.
;
; Memory layout: tests use RAM at 0x8100

    .module bit_ix_iy

_sim_ctl_port = 0x80
_timeout_port = 0x82
FLAG_Z  = 0x40
FLAG_H  = 0x10
FLAG_N  = 0x02
MEM_BASE = 0x8100

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100

heartbeat:
    push af
    ld   a, #0x02
    out  (_timeout_port), a
    ld   a, #0x01
    out  (_timeout_port), a
    pop  af
    ret

main:
    ld  sp, #0xFFFF
    ld  ix, #MEM_BASE
    ld  iy, #MEM_BASE

    ;========================================================
    ; BIT-04a: BIT b,(IX+d)
    ;========================================================
    call heartbeat

    ; BIT 0,(IX+0): mem[0]=0x01, bit0=1 → Z=0, H=1, N=0
    ld  hl, #MEM_BASE
    ld  (hl), #0x01
    .db 0xDD, 0xCB, 0x00, 0x46  ; BIT 0,(IX+0)  [0x46 = 0x40+0*8+6]
    jp  z,   test_fail          ; Z must be clear (bit IS set)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_H
    jp   z,  test_fail          ; H must be set
    ld   a, c
    and  a, #FLAG_N
    jp   nz, test_fail          ; N must be clear

    ; BIT 0,(IX+0): mem[0]=0xFE, bit0=0 → Z=1
    ld  hl, #MEM_BASE
    ld  (hl), #0xFE
    .db 0xDD, 0xCB, 0x00, 0x46  ; BIT 0,(IX+0)
    jp  nz,  test_fail          ; Z must be set (bit NOT set)

    ; BIT 7,(IX+1): mem[1]=0x80, bit7=1 → Z=0
    ld  hl, #MEM_BASE+1
    ld  (hl), #0x80
    .db 0xDD, 0xCB, 0x01, 0x7E  ; BIT 7,(IX+1)  [0x7E = 0x40+7*8+6]
    jp  z,   test_fail          ; Z must be clear

    ; BIT 7,(IX+1): mem[1]=0x7F, bit7=0 → Z=1
    ld  hl, #MEM_BASE+1
    ld  (hl), #0x7F
    .db 0xDD, 0xCB, 0x01, 0x7E  ; BIT 7,(IX+1)
    jp  nz,  test_fail          ; Z must be set

    ; BIT 3,(IX+2): mem[2]=0x08, bit3=1 → Z=0
    ld  hl, #MEM_BASE+2
    ld  (hl), #0x08
    .db 0xDD, 0xCB, 0x02, 0x5E  ; BIT 3,(IX+2)  [0x5E = 0x40+3*8+6]
    jp  z,   test_fail

    ;========================================================
    ; BIT-04b: BIT b,(IY+d)
    ;========================================================
    call heartbeat

    ; BIT 0,(IY+0): mem[0]=0x01 → Z=0
    ld  hl, #MEM_BASE
    ld  (hl), #0x01
    .db 0xFD, 0xCB, 0x00, 0x46  ; BIT 0,(IY+0)
    jp  z,   test_fail

    ; BIT 0,(IY+0): mem[0]=0xFE → Z=1
    ld  hl, #MEM_BASE
    ld  (hl), #0xFE
    .db 0xFD, 0xCB, 0x00, 0x46  ; BIT 0,(IY+0)
    jp  nz,  test_fail

    ; BIT 4,(IY+3): mem[3]=0x10 → Z=0
    ld  hl, #MEM_BASE+3
    ld  (hl), #0x10
    .db 0xFD, 0xCB, 0x03, 0x66  ; BIT 4,(IY+3)  [0x66 = 0x40+4*8+6]
    jp  z,   test_fail

    ;========================================================
    ; BIT-04c: SET b,(IX+d) — verify memory bit is set
    ;========================================================
    call heartbeat

    ; SET 0,(IX+0): mem[0]=0x00 → 0x01
    ld  hl, #MEM_BASE
    ld  (hl), #0x00
    .db 0xDD, 0xCB, 0x00, 0xC6  ; SET 0,(IX+0)  [0xC6 = 0xC0+0*8+6]
    ld  a, (hl)
    cp  a, #0x01
    jp  nz, test_fail

    ; SET 7,(IX+2): mem[2]=0x00 → 0x80
    ld  hl, #MEM_BASE+2
    ld  (hl), #0x00
    .db 0xDD, 0xCB, 0x02, 0xFE  ; SET 7,(IX+2)  [0xFE = 0xC0+7*8+6]
    ld  a, (hl)
    cp  a, #0x80
    jp  nz, test_fail

    ; SET 3,(IX+4): mem[4]=0x00 → 0x08
    ld  hl, #MEM_BASE+4
    ld  (hl), #0x00
    .db 0xDD, 0xCB, 0x04, 0xDE  ; SET 3,(IX+4)  [0xDE = 0xC0+3*8+6]
    ld  a, (hl)
    cp  a, #0x08
    jp  nz, test_fail

    ; SET 5,(IX+0): verify non-zero starting value also works
    ld  hl, #MEM_BASE
    ld  (hl), #0x01             ; bit0 already set
    .db 0xDD, 0xCB, 0x00, 0xEE  ; SET 5,(IX+0)  [0xEE = 0xC0+5*8+6]
    ld  a, (hl)
    cp  a, #0x21                ; bit0 | bit5 = 0x01 | 0x20 = 0x21
    jp  nz, test_fail

    ;========================================================
    ; BIT-04d: SET b,(IY+d)
    ;========================================================
    call heartbeat

    ; SET 3,(IY+1): mem[1]=0x00 → 0x08
    ld  hl, #MEM_BASE+1
    ld  (hl), #0x00
    .db 0xFD, 0xCB, 0x01, 0xDE  ; SET 3,(IY+1)  [0xDE = 0xC0+3*8+6]
    ld  a, (hl)
    cp  a, #0x08
    jp  nz, test_fail

    ; SET 6,(IY+5): mem[5]=0x00 → 0x40
    ld  hl, #MEM_BASE+5
    ld  (hl), #0x00
    .db 0xFD, 0xCB, 0x05, 0xF6  ; SET 6,(IY+5)  [0xF6 = 0xC0+6*8+6]
    ld  a, (hl)
    cp  a, #0x40
    jp  nz, test_fail

    ;========================================================
    ; BIT-04e: RES b,(IX+d) — verify memory bit is cleared
    ;========================================================
    call heartbeat

    ; RES 0,(IX+0): mem[0]=0xFF → 0xFE
    ld  hl, #MEM_BASE
    ld  (hl), #0xFF
    .db 0xDD, 0xCB, 0x00, 0x86  ; RES 0,(IX+0)  [0x86 = 0x80+0*8+6]
    ld  a, (hl)
    cp  a, #0xFE
    jp  nz, test_fail

    ; RES 7,(IX+1): mem[1]=0xFF → 0x7F
    ld  hl, #MEM_BASE+1
    ld  (hl), #0xFF
    .db 0xDD, 0xCB, 0x01, 0xBE  ; RES 7,(IX+1)  [0xBE = 0x80+7*8+6]
    ld  a, (hl)
    cp  a, #0x7F
    jp  nz, test_fail

    ; RES 4,(IX+3): mem[3]=0xFF → 0xEF
    ld  hl, #MEM_BASE+3
    ld  (hl), #0xFF
    .db 0xDD, 0xCB, 0x03, 0xA6  ; RES 4,(IX+3)  [0xA6 = 0x80+4*8+6]
    ld  a, (hl)
    cp  a, #0xEF
    jp  nz, test_fail

    ;========================================================
    ; BIT-04f: RES b,(IY+d)
    ;========================================================
    call heartbeat

    ; RES 7,(IY+0): mem[0]=0xFF → 0x7F
    ld  hl, #MEM_BASE
    ld  (hl), #0xFF
    .db 0xFD, 0xCB, 0x00, 0xBE  ; RES 7,(IY+0)  [0xBE = 0x80+7*8+6]
    ld  a, (hl)
    cp  a, #0x7F
    jp  nz, test_fail

    ; RES 0,(IY+2): mem[2]=0xFF → 0xFE
    ld  hl, #MEM_BASE+2
    ld  (hl), #0xFF
    .db 0xFD, 0xCB, 0x02, 0x86  ; RES 0,(IY+2)  [0x86 = 0x80+0*8+6]
    ld  a, (hl)
    cp  a, #0xFE
    jp  nz, test_fail

    ;========================================================
    ; BIT-04g: Negative displacement (signed byte)
    ;   IX points to MEM_BASE; displacement −1 (0xFF) points to MEM_BASE−1
    ;   Use IX = MEM_BASE+1 so IX+0xFF wraps to MEM_BASE
    ;========================================================
    call heartbeat
    ld  ix, #MEM_BASE+1
    ld  hl, #MEM_BASE
    ld  (hl), #0xA5

    ; BIT 0,(IX-1): mem[MEM_BASE]=0xA5, bit0=1 → Z=0
    .db 0xDD, 0xCB, 0xFF, 0x46  ; BIT 0,(IX+0xFF) = BIT 0,(IX-1)
    jp  z,   test_fail

    ; SET 1,(IX-1): mem[MEM_BASE] set bit1 → 0xA7
    .db 0xDD, 0xCB, 0xFF, 0xCE  ; SET 1,(IX-1)  [0xCE = 0xC0+1*8+6]
    ld  a, (hl)
    cp  a, #0xA7
    jp  nz, test_fail

    ; Restore IX
    ld  ix, #MEM_BASE

    ;--- PASS ---
    ld   a, #0x01
    out  (_sim_ctl_port), a
    halt

test_fail:
    ld   a, #0x02
    out  (_sim_ctl_port), a
    halt
