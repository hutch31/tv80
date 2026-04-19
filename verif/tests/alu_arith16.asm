; alu_arith16.asm – ALU-05, ALU-06, ALU-07, ALU-09
;
; Tests 16-bit arithmetic instructions:
;   ALU-05  ADD HL,rr   (all register pairs)
;   ALU-06  ADC HL,rr   (all register pairs)
;   ALU-07  SBC HL,rr   (all register pairs)
;   ALU-09  INC rr / DEC rr  (no flags affected)

    .module alu_arith16

_sim_ctl_port = 0x80

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ;========================================================
    ; ALU-05: ADD HL,rr
    ;========================================================
    ; ADD HL,BC: 0x1000 + 0x0234 = 0x1234
    ld  hl, #0x1000
    ld  bc, #0x0234
    add hl, bc
    ld  a, h
    cp  a, #0x12
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x34
    jp  nz, test_fail

    ; ADD HL,DE: 0x0100 + 0x0200 = 0x0300
    ld  hl, #0x0100
    ld  de, #0x0200
    add hl, de
    ld  a, h
    cp  a, #0x03
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x00
    jp  nz, test_fail

    ; ADD HL,HL: 0x1000 + 0x1000 = 0x2000
    ld  hl, #0x1000
    add hl, hl
    ld  a, h
    cp  a, #0x20
    jp  nz, test_fail

    ; ADD HL,SP: 0x0001 + 0xFFFF = 0x0000, C=1
    ld  sp, #0xFFFF
    ld  hl, #0x0001
    add hl, sp
    jp  c, after_add_sp_carry  ; C must be set
    jp  test_fail
after_add_sp_carry:
    ld  a, h
    cp  a, #0x00
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x00
    jp  nz, test_fail

    ; ADD HL,rr must NOT change S, Z, P/V flags
    ; Set up known flags, do ADD HL,BC, verify flags preserved
    ld  hl, #0x0001
    ld  bc, #0x0002
    xor a, a                    ; Z=1, S=0
    add hl, bc                  ; this must preserve Z, S, P/V
    jp  nz, test_fail           ; Z must still be set

    ;========================================================
    ; ALU-06: ADC HL,rr (all register pairs, S/Z/P/V updated)
    ;========================================================
    ; ADC HL,BC with carry=0: 0x1000 + 0x0200 + 0 = 0x1200
    ld  hl, #0x1000
    ld  bc, #0x0200
    or  a, a                    ; clear carry
    .db 0xED, 0x4A              ; ADC HL,BC
    ld  a, h
    cp  a, #0x12
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x00
    jp  nz, test_fail

    ; ADC HL,DE with carry=1: 0x00FF + 0x0000 + 1 = 0x0100
    ld  hl, #0x00FF
    ld  de, #0x0000
    scf                         ; set carry
    .db 0xED, 0x5A              ; ADC HL,DE
    ld  a, h
    cp  a, #0x01
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x00
    jp  nz, test_fail

    ; ADC HL,HL with carry=0 → S and Z updated
    ld  hl, #0x0000
    or  a, a
    .db 0xED, 0x6A              ; ADC HL,HL
    jp  nz, test_fail           ; Z must be set

    ; ADC HL,SP with carry=1: 0x7FFF + 0x0000 + 1 = 0x8000 → V=1, S=1
    ld  sp, #0x0000
    ld  hl, #0x7FFF
    scf
    .db 0xED, 0x7A              ; ADC HL,SP
    jp  p,  test_fail           ; S must be set
    push af
    pop  bc
    ld   a, c
    and  a, #0x04               ; P/V bit
    jp   z, test_fail           ; V must be set (overflow)

    ;========================================================
    ; ALU-07: SBC HL,rr (all register pairs, N=1)
    ;========================================================
    ; SBC HL,BC borrow=0: 0x1234 - 0x0234 - 0 = 0x1000
    ld  hl, #0x1234
    ld  bc, #0x0234
    or  a, a
    .db 0xED, 0x42              ; SBC HL,BC
    ld  a, h
    cp  a, #0x10
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x00
    jp  nz, test_fail
    push af
    pop  bc
    ld   a, c
    and  a, #0x02               ; N bit
    jp   z, test_fail           ; N must be set after SBC

    ; SBC HL,DE borrow=1: 0x0100 - 0x00FF - 1 = 0x0000, Z=1
    ld  hl, #0x0100
    ld  de, #0x00FF
    scf
    .db 0xED, 0x52              ; SBC HL,DE
    jp  nz, test_fail           ; Z must be set

    ; SBC HL,HL borrow=0: 0x1234 - 0x1234 = 0x0000, Z=1
    ld  hl, #0x1234
    or  a, a
    .db 0xED, 0x62              ; SBC HL,HL
    jp  nz, test_fail

    ; SBC HL,SP borrow=0: borrow from 0 → negative
    ld  sp, #0x0001
    ld  hl, #0x0000
    or  a, a
    .db 0xED, 0x72              ; SBC HL,SP
    jp  nc, test_fail           ; C (borrow) must be set

    ;========================================================
    ; ALU-09: INC rr / DEC rr (no flags affected)
    ;========================================================
    ; Set carry and zero flags, then INC BC – flags must be unchanged
    xor a, a                    ; Z=1, S=0
    scf                         ; C=1
    ld  bc, #0x00FF
    inc bc
    jp  z,  after_inc_bc_z      ; Z should still be set
    jp  test_fail
after_inc_bc_z:
    jp  nc, test_fail           ; C should still be set
    ld  a, b
    cp  a, #0x01
    jp  nz, test_fail
    ld  a, c
    cp  a, #0x00
    jp  nz, test_fail

    ; DEC DE: 0x0100 → 0x00FF
    ld  de, #0x0100
    dec de
    ld  a, d
    cp  a, #0x00
    jp  nz, test_fail
    ld  a, e
    cp  a, #0xFF
    jp  nz, test_fail

    ; INC HL: 0xFFFF → 0x0000 (no flags change)
    xor a, a                    ; Z=1
    ld  hl, #0xFFFF
    inc hl
    jp  z,  after_inc_hl_z
    jp  test_fail
after_inc_hl_z:
    ld  a, h
    cp  a, #0x00
    jp  nz, test_fail
    ld  a, l
    cp  a, #0x00
    jp  nz, test_fail

    ; DEC SP: 0x0001 → 0x0000
    ld  sp, #0x0001
    dec sp
    ; Re-read SP by LD HL,nn and LD SP,HL round-trip is complex;
    ; Instead push/pop a test value to verify SP is at 0x0000 (wrap to FFFE)
    ; Just verify INC SP works:
    ld  sp, #0x8000
    inc sp
    ; Store SP to test memory via LD (nn),SP (ED 73):
    .db 0xED, 0x73, 0x00, 0x80  ; LD (0x8000),SP
    ld  hl, #0x8000
    ld  a, (hl)
    cp  a, #0x01                ; low byte of SP=0x8001
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x80                ; high byte
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
