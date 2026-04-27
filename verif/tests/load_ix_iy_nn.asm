; load_ix_iy_nn.asm – LD-16
;
; Tests IX/IY indirect memory instructions that require 6+ machine cycles,
; targeting the mcycle[5] prefix-detection path and the mcycle[6] IR/ISet
; latch paths in Tv80Core.
;
; Instructions covered:
;   LD IX,(nn)   = DD 2A lo hi   (6 M-cycles; mcycle[5] reached)
;   LD (nn),IX   = DD 22 lo hi   (6 M-cycles)
;   LD IY,(nn)   = FD 2A lo hi   (6 M-cycles)
;   LD (nn),IY   = FD 22 lo hi   (6 M-cycles)
;   LD (IX+d),n  = DD 36 d n     (6 M-cycles; exercises dd-prefix + immediate store)
;   LD (IY+d),n  = FD 36 d n     (6 M-cycles)
;
; Note: LD IX,(nn) also appears in load_mem.asm (LD-11), but here we
; exercise more displacement values and the IY form to maximise the
; mcycle[5] coverage count.

    .module load_ix_iy_nn

_sim_ctl_port = 0x80
_timeout_port = 0x82
MEM_BASE = 0x8200

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

    ;========================================================
    ; LD-16a: LD (nn),IX / LD IX,(nn)  (DD 22 / DD 2A)
    ;========================================================
    call heartbeat

    ; Store IX=0x1234 to memory then reload
    .db 0xDD, 0x21, 0x34, 0x12  ; LD IX,0x1234
    .db 0xDD, 0x22, 0x00, 0x82  ; LD (0x8200),IX
    ; Verify raw bytes
    ld  hl, #MEM_BASE
    ld  a, (hl)
    cp  a, #0x34                ; IXL (low byte first)
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x12                ; IXH
    jp  nz, test_fail
    ; Reload
    .db 0xDD, 0x21, 0x00, 0x00  ; LD IX,0x0000 (clear IX first)
    .db 0xDD, 0x2A, 0x00, 0x82  ; LD IX,(0x8200)
    ; Read IX via PUSH IX / POP HL
    .db 0xDD, 0xE5              ; PUSH IX
    pop  hl
    ld   a, h
    cp   a, #0x12               ; IXH
    jp   nz, test_fail
    ld   a, l
    cp   a, #0x34               ; IXL
    jp   nz, test_fail

    ; Store IX=0x8FFE (boundary value)
    .db 0xDD, 0x21, 0xFE, 0x8F  ; LD IX,0x8FFE
    .db 0xDD, 0x22, 0x02, 0x82  ; LD (0x8202),IX
    .db 0xDD, 0x2A, 0x02, 0x82  ; LD IX,(0x8202)
    .db 0xDD, 0xE5              ; PUSH IX
    pop  hl
    ld   a, h
    cp   a, #0x8F
    jp   nz, test_fail
    ld   a, l
    cp   a, #0xFE
    jp   nz, test_fail

    ;========================================================
    ; LD-16b: LD (nn),IY / LD IY,(nn)  (FD 22 / FD 2A)
    ;========================================================
    call heartbeat

    .db 0xFD, 0x21, 0x78, 0x56  ; LD IY,0x5678
    .db 0xFD, 0x22, 0x04, 0x82  ; LD (0x8204),IY
    ld  hl, #MEM_BASE+4
    ld  a, (hl)
    cp  a, #0x78
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x56
    jp  nz, test_fail

    .db 0xFD, 0x21, 0x00, 0x00  ; LD IY,0x0000
    .db 0xFD, 0x2A, 0x04, 0x82  ; LD IY,(0x8204)
    .db 0xFD, 0xE5              ; PUSH IY
    pop  hl
    ld   a, h
    cp   a, #0x56
    jp   nz, test_fail
    ld   a, l
    cp   a, #0x78
    jp   nz, test_fail

    ;========================================================
    ; LD-16c: LD (IX+d),n  (DD 36 d n) — immediate-to-indexed write
    ;========================================================
    call heartbeat

    .db 0xDD, 0x21, 0x00, 0x82  ; LD IX,MEM_BASE (0x8200)

    ; LD (IX+0),0xAB
    .db 0xDD, 0x36, 0x00, 0xAB  ; LD (IX+0),0xAB
    ld  hl, #MEM_BASE
    ld  a, (hl)
    cp  a, #0xAB
    jp  nz, test_fail

    ; LD (IX+1),0xCD
    .db 0xDD, 0x36, 0x01, 0xCD  ; LD (IX+1),0xCD
    ld  hl, #MEM_BASE+1
    ld  a, (hl)
    cp  a, #0xCD
    jp  nz, test_fail

    ; LD (IX+5),0xFF — larger positive displacement
    .db 0xDD, 0x36, 0x05, 0xFF  ; LD (IX+5),0xFF
    ld  hl, #MEM_BASE+5
    ld  a, (hl)
    cp  a, #0xFF
    jp  nz, test_fail

    ; LD (IX+0xFF),0x55 — displacement 0xFF = signed −1 means IX−1 = MEM_BASE−1 = 0x81FF
    ; Use IX = MEM_BASE+1 so that (IX+0xFF) = 0x8200 (wraps around)
    .db 0xDD, 0x21, 0x01, 0x82  ; LD IX,MEM_BASE+1
    .db 0xDD, 0x36, 0xFF, 0x55  ; LD (IX-1),0x55
    ld  hl, #MEM_BASE
    ld  a, (hl)
    cp  a, #0x55
    jp  nz, test_fail

    ;========================================================
    ; LD-16d: LD (IY+d),n  (FD 36 d n)
    ;========================================================
    call heartbeat

    .db 0xFD, 0x21, 0x10, 0x82  ; LD IY,MEM_BASE+0x10 (0x8210)

    ; LD (IY+0),0x12
    .db 0xFD, 0x36, 0x00, 0x12  ; LD (IY+0),0x12
    ld  hl, #MEM_BASE+0x10
    ld  a, (hl)
    cp  a, #0x12
    jp  nz, test_fail

    ; LD (IY+3),0x34
    .db 0xFD, 0x36, 0x03, 0x34  ; LD (IY+3),0x34
    ld  hl, #MEM_BASE+0x13
    ld  a, (hl)
    cp  a, #0x34
    jp  nz, test_fail

    ; LD (IY+0),0x00 — write zero
    .db 0xFD, 0x36, 0x00, 0x00  ; LD (IY+0),0x00
    ld  hl, #MEM_BASE+0x10
    ld  a, (hl)
    cp  a, #0x00
    jp  nz, test_fail

    ;--- PASS ---
    ld   a, #0x01
    out  (_sim_ctl_port), a
    halt

test_fail:
    ld   a, #0x02
    out  (_sim_ctl_port), a
    halt
