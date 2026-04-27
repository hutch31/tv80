; block_search.asm – BLK-01..02
;
; Tests Z80 block-compare instructions:
;   BLK-01  CPI  (ED A1): compare A with (HL), HL++, BC--
;   BLK-01  CPD  (ED A9): compare A with (HL), HL--, BC--
;   BLK-02  CPIR (ED B1): repeat CPI until Z=1 (A==(HL)) or BC=0
;   BLK-02  CPDR (ED B9): repeat CPD until Z=1 or BC=0
;
; These exercise the io_I_BC microcode signal path in Tv80Mcode.
;
; Flag conventions for CPI/CPD:
;   Z   = 1 if A == (HL)
;   P/V = 1 if BC-1 != 0 after decrement (i.e., more elements remain)
;   H   = borrow from bit 4 of comparison
;   N   = 1 always
;   S, C = unchanged
;
; Memory layout: tests use RAM at 0x8300..0x8310

    .module block_search

_sim_ctl_port = 0x80
_timeout_port = 0x82
FLAG_Z  = 0x40
FLAG_PV = 0x04
MEM_BASE = 0x8300

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

;------------------------------------------------------------------
; fill_mem: fill MEM_BASE+0..2 with 0xAA, 0xBB, 0xCC
;------------------------------------------------------------------
fill_mem:
    ld  hl, #MEM_BASE
    ld  (hl), #0xAA
    inc hl
    ld  (hl), #0xBB
    inc hl
    ld  (hl), #0xCC
    ret

main:
    ld  sp, #0xFFFF
    call fill_mem

    ;========================================================
    ; BLK-01a: CPI — match on first element
    ;   A=0xAA, HL=MEM_BASE, BC=3
    ;   After CPI: Z=1 (matched), P/V=1 (BC=2 != 0), HL=MEM_BASE+1, BC=2
    ;========================================================
    call heartbeat
    ld  hl, #MEM_BASE
    ld  bc, #3
    ld  a, #0xAA
    .db 0xED, 0xA1              ; CPI
    jp  nz, test_fail           ; Z must be set (matched)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   z,  test_fail          ; P/V must be set (BC=2 != 0)
    ; Verify HL advanced to MEM_BASE+1
    ld  a, l
    cp  a, #((MEM_BASE+1) & 0xFF)
    jp  nz, test_fail

    ;========================================================
    ; BLK-01b: CPI — no match, BC exhausted
    ;   A=0xAA, HL=MEM_BASE+1 (points to 0xBB), BC=1
    ;   After CPI: Z=0 (no match), P/V=0 (BC=0)
    ;========================================================
    call heartbeat
    ld  hl, #MEM_BASE+1
    ld  bc, #1
    ld  a, #0xAA
    .db 0xED, 0xA1              ; CPI on (MEM_BASE+1)=0xBB
    jp  z,   test_fail          ; Z must be clear (no match)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   nz, test_fail          ; P/V must be clear (BC=0)

    ;========================================================
    ; BLK-01c: CPD — match on current element, HL decrements
    ;   A=0xCC, HL=MEM_BASE+2 (points to 0xCC), BC=3
    ;   After CPD: Z=1, P/V=1 (BC=2), HL=MEM_BASE+1
    ;========================================================
    call heartbeat
    ld  hl, #MEM_BASE+2
    ld  bc, #3
    ld  a, #0xCC
    .db 0xED, 0xA9              ; CPD
    jp  nz, test_fail           ; Z must be set (matched)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   z,  test_fail          ; P/V must be set (BC=2)
    ; Verify HL decremented to MEM_BASE+1
    ld  a, l
    cp  a, #((MEM_BASE+1) & 0xFF)
    jp  nz, test_fail

    ;========================================================
    ; BLK-01d: CPD — no match, P/V=0 (BC exhausted)
    ;   A=0xFF, HL=MEM_BASE+2, BC=1
    ;   After CPD: Z=0, P/V=0
    ;========================================================
    call heartbeat
    ld  hl, #MEM_BASE+2
    ld  bc, #1
    ld  a, #0xFF
    .db 0xED, 0xA9              ; CPD on (MEM_BASE+2)=0xCC
    jp  z,   test_fail          ; Z must be clear
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   nz, test_fail          ; P/V must be clear (BC=0)

    ;========================================================
    ; BLK-02a: CPIR — match found before BC exhausted
    ;   A=0xBB, HL=MEM_BASE, BC=3
    ;   Memory: [0]=0xAA [1]=0xBB [2]=0xCC
    ;   CPIR iterates: 0xAA≠0xBB (cont), 0xBB==0xBB (stop)
    ;   After: Z=1, P/V=1 (BC=1), HL=MEM_BASE+2
    ;========================================================
    call heartbeat
    call fill_mem
    ld  hl, #MEM_BASE
    ld  bc, #3
    ld  a, #0xBB
    .db 0xED, 0xB1              ; CPIR
    jp  nz, test_fail           ; Z must be set (found)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   z,  test_fail          ; P/V must be set (BC=1 after match)
    ; HL should be MEM_BASE+2 (one past the matched element)
    ld  a, l
    cp  a, #((MEM_BASE+2) & 0xFF)
    jp  nz, test_fail

    ;========================================================
    ; BLK-02b: CPIR — no match; BC exhausted
    ;   A=0xFF (not in array), HL=MEM_BASE, BC=3
    ;   After CPIR: Z=0, P/V=0, HL=MEM_BASE+3
    ;========================================================
    call heartbeat
    ld  hl, #MEM_BASE
    ld  bc, #3
    ld  a, #0xFF
    .db 0xED, 0xB1              ; CPIR — exhausts without match
    jp  z,   test_fail          ; Z must be clear (not found)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   nz, test_fail          ; P/V must be clear (BC=0)

    ;========================================================
    ; BLK-02c: CPDR — match found searching backwards
    ;   A=0xAA, HL=MEM_BASE+2, BC=4 (> array size so P/V=1 at match)
    ;   Memory: [0]=0xAA [1]=0xBB [2]=0xCC
    ;   CPDR iterates: 0xCC≠0xAA, 0xBB≠0xAA, 0xAA==0xAA (stop)
    ;   After: Z=1, P/V=1 (BC=1), HL=MEM_BASE-1
    ;========================================================
    call heartbeat
    call fill_mem
    ld  hl, #MEM_BASE+2
    ld  bc, #4
    ld  a, #0xAA
    .db 0xED, 0xB9              ; CPDR
    jp  nz, test_fail           ; Z must be set (found)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   z,  test_fail          ; P/V must be set (BC=1)

    ;========================================================
    ; BLK-02d: CPDR — no match; BC exhausted
    ;   A=0xFF, HL=MEM_BASE+2, BC=3
    ;   After CPDR: Z=0, P/V=0
    ;========================================================
    call heartbeat
    ld  hl, #MEM_BASE+2
    ld  bc, #3
    ld  a, #0xFF
    .db 0xED, 0xB9              ; CPDR — exhausts
    jp  z,   test_fail          ; Z must be clear
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   nz, test_fail          ; P/V must be clear

    ;========================================================
    ; BLK-02e: CPIR with BC=1, match on first (and only) element
    ;   A=0xAA, HL=MEM_BASE, BC=1
    ;   After CPIR: Z=1, P/V=0 (BC becomes 0), HL=MEM_BASE+1
    ;========================================================
    call heartbeat
    ld  hl, #MEM_BASE
    ld  bc, #1
    ld  a, #0xAA
    .db 0xED, 0xB1              ; CPIR
    jp  nz, test_fail           ; Z=1 (found)
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   nz, test_fail          ; P/V=0 (BC became 0)

    ;--- PASS ---
    ld   a, #0x01
    out  (_sim_ctl_port), a
    halt

test_fail:
    ld   a, #0x02
    out  (_sim_ctl_port), a
    halt
