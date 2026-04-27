; load_sp_hl.asm – LD-15
;
; Dedicated test for LD SP,HL / LD SP,IX / LD SP,IY.
; These instructions copy the 16-bit register pair into SP using the
; LDSPHL microcode path in Tv80Core (SP <= RegBusC).
;
; Verification method: load a known value into the register pair, execute
; LD SP,<rr>, then store SP to memory via "LD (nn),SP" (ED 73) and read
; back to confirm SP was updated correctly.
;
; SP is restored to 0xFFFF between each subtest to keep the stack usable.

    .module load_sp_hl

_sim_ctl_port = 0x80
_timeout_port = 0x82
; Scratch RAM locations for SP readback
SP_READBACK = 0x8010

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
    ; LD-15a: LD SP,HL (opcode 0xF9)
    ;========================================================
    call heartbeat

    ; Case 1: LD SP,HL where HL=0x8FFE
    ld  hl, #0x8FFE
    ld  sp, hl                      ; LD SP,HL
    .db 0xED, 0x73, 0x10, 0x80      ; LD (SP_READBACK),SP = LD (0x8010),SP
    ld  hl, #SP_READBACK
    ld  a, (hl)
    cp  a, #0xFE                    ; low byte of 0x8FFE
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x8F                    ; high byte
    jp  nz, test_fail

    ld  sp, #0xFFFF                 ; restore SP

    ; Case 2: LD SP,HL where HL=0x1234
    ld  hl, #0x1234
    ld  sp, hl
    .db 0xED, 0x73, 0x10, 0x80      ; LD (0x8010),SP
    ld  hl, #SP_READBACK
    ld  a, (hl)
    cp  a, #0x34
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x12
    jp  nz, test_fail

    ld  sp, #0xFFFF

    ; Case 3: LD SP,HL where HL=0x0000
    ld  hl, #0x0000
    ld  sp, hl
    .db 0xED, 0x73, 0x10, 0x80      ; LD (0x8010),SP
    ld  hl, #SP_READBACK
    ld  a, (hl)
    cp  a, #0x00
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x00
    jp  nz, test_fail

    ld  sp, #0xFFFF

    ;========================================================
    ; LD-15b: LD SP,IX (opcode DD F9)
    ;========================================================
    call heartbeat

    .db 0xDD, 0x21, 0x78, 0x56      ; LD IX,0x5678
    .db 0xDD, 0xF9                  ; LD SP,IX
    .db 0xED, 0x73, 0x10, 0x80      ; LD (0x8010),SP
    ld  hl, #SP_READBACK
    ld  a, (hl)
    cp  a, #0x78
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x56
    jp  nz, test_fail

    ld  sp, #0xFFFF

    ; IX=0x8FFE (valid stack pointer value)
    .db 0xDD, 0x21, 0xFE, 0x8F      ; LD IX,0x8FFE
    .db 0xDD, 0xF9                  ; LD SP,IX
    .db 0xED, 0x73, 0x10, 0x80      ; LD (0x8010),SP
    ld  hl, #SP_READBACK
    ld  a, (hl)
    cp  a, #0xFE
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x8F
    jp  nz, test_fail

    ld  sp, #0xFFFF

    ;========================================================
    ; LD-15c: LD SP,IY (opcode FD F9)
    ;========================================================
    call heartbeat

    .db 0xFD, 0x21, 0xBC, 0x9A      ; LD IY,0x9ABC
    .db 0xFD, 0xF9                  ; LD SP,IY
    .db 0xED, 0x73, 0x10, 0x80      ; LD (0x8010),SP
    ld  hl, #SP_READBACK
    ld  a, (hl)
    cp  a, #0xBC
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x9A
    jp  nz, test_fail

    ld  sp, #0xFFFF

    ; IY=0x8000 (boundary value)
    .db 0xFD, 0x21, 0x00, 0x80      ; LD IY,0x8000
    .db 0xFD, 0xF9                  ; LD SP,IY
    .db 0xED, 0x73, 0x10, 0x80      ; LD (0x8010),SP
    ld  hl, #SP_READBACK
    ld  a, (hl)
    cp  a, #0x00
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x80
    jp  nz, test_fail

    ld  sp, #0xFFFF

    ;--- PASS ---
    ld   a, #0x01
    out  (_sim_ctl_port), a
    halt

test_fail:
    ld  sp, #0xFFFF                 ; ensure stack is sane before halt
    ld   a, #0x02
    out  (_sim_ctl_port), a
    halt
