; stack_ops.asm – STK-01..02
;
;   STK-01  PUSH/POP for AF, BC, DE, HL, IX, IY
;   STK-02  EX (SP),HL / EX (SP),IX / EX (SP),IY

    .module stack_ops

_sim_ctl_port = 0x80
_timeout_port = 0x82

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100

;------------------------------------------------------------------
; Reset the simulation timeout counter (heartbeat at each section)
;------------------------------------------------------------------
heartbeat:
    push af
    ld   a, #0x02
    out  (_timeout_port), a     ; reset counter
    ld   a, #0x01
    out  (_timeout_port), a     ; re-enable counting
    pop  af
    ret

main:
    ld  sp, #0xFFFF

    ;========================================================
    ; STK-01: PUSH/POP
    ;========================================================
    call heartbeat
    ; PUSH BC / POP DE: verify DE = original BC
    ld  bc, #0x1234
    push bc
    pop  de
    ld  a, d
    cp  a, #0x12
    jp  nz, test_fail
    ld  a, e
    cp  a, #0x34
    jp  nz, test_fail

    ; PUSH DE / POP HL
    ld  de, #0xABCD
    push de
    pop  hl
    ld  a, h
    cp  a, #0xAB
    jp  nz, test_fail
    ld  a, l
    cp  a, #0xCD
    jp  nz, test_fail

    ; PUSH HL / POP BC
    ld  hl, #0x5A5A
    push hl
    pop  bc
    ld  a, b
    cp  a, #0x5A
    jp  nz, test_fail
    ld  a, c
    cp  a, #0x5A
    jp  nz, test_fail

    ; PUSH AF / POP AF: verify flags preserved
    ; Set known flags: carry set, zero clear
    scf
    ld  a, #0x55
    push af
    xor a, a                ; destroy A and flags
    pop  af
    jp  nc, test_fail       ; carry must be restored
    cp  a, #0x55
    jp  nz, test_fail

    ; Nested PUSH/POP: stack discipline
    ld  bc, #0x1111
    ld  de, #0x2222
    ld  hl, #0x3333
    push bc
    push de
    push hl
    pop  bc                 ; BC should get HL's value
    pop  de                 ; DE should get original DE
    pop  hl                 ; HL should get original BC
    ld  a, b
    cp  a, #0x33
    jp  nz, test_fail
    ld  a, d
    cp  a, #0x22
    jp  nz, test_fail
    ld  a, h
    cp  a, #0x11
    jp  nz, test_fail

    ; PUSH IX / POP IX
    .db 0xDD, 0x21, 0xBE, 0xEF  ; LD IX,0xEFBE
    .db 0xDD, 0xE5              ; PUSH IX
    .db 0xDD, 0xE1              ; POP IX
    .db 0xDD, 0x7C              ; LD A,IXH
    cp  a, #0xEF
    jp  nz, test_fail
    .db 0xDD, 0x7D              ; LD A,IXL
    cp  a, #0xBE
    jp  nz, test_fail

    ; PUSH IY / POP IY
    .db 0xFD, 0x21, 0xCA, 0xFE  ; LD IY,0xFECA
    .db 0xFD, 0xE5              ; PUSH IY
    .db 0xFD, 0xE1              ; POP IY
    .db 0xFD, 0x7C              ; LD A,IYH
    cp  a, #0xFE
    jp  nz, test_fail
    .db 0xFD, 0x7D              ; LD A,IYL
    cp  a, #0xCA
    jp  nz, test_fail

    ; Cross: PUSH IX / POP IY
    .db 0xDD, 0x21, 0x12, 0x34  ; LD IX,0x3412
    .db 0xDD, 0xE5              ; PUSH IX
    .db 0xFD, 0xE1              ; POP IY
    .db 0xFD, 0x7C              ; LD A,IYH
    cp  a, #0x34
    jp  nz, test_fail
    .db 0xFD, 0x7D
    cp  a, #0x12
    jp  nz, test_fail

    ;========================================================
    ; STK-02: EX (SP),HL / EX (SP),IX / EX (SP),IY
    ;========================================================
    call heartbeat
    ; EX (SP),HL: swap HL with top of stack
    ld  sp, #0x8FFE
    ld  hl, #0xABCD
    push hl                 ; (0x8FFE) = 0xCD, (0x8FFF) = 0xAB
    ld  hl, #0x1234         ; HL = 0x1234, stack top = 0xABCD
    ex  (sp), hl            ; HL ↔ (SP): HL=0xABCD, stack top = 0x1234
    ld  a, h
    cp  a, #0xAB
    jp  nz, test_fail
    ld  a, l
    cp  a, #0xCD
    jp  nz, test_fail
    pop  de                 ; recover 0x1234 from stack
    ld  a, d
    cp  a, #0x12
    jp  nz, test_fail
    ld  a, e
    cp  a, #0x34
    jp  nz, test_fail

    ; EX (SP),IX
    ld  sp, #0x8FFE
    .db 0xDD, 0x21, 0xAA, 0xBB  ; LD IX,0xBBAA
    .db 0xDD, 0xE5              ; PUSH IX  → stack top = 0xBBAA
    .db 0xDD, 0x21, 0x11, 0x22  ; LD IX,0x2211
    .db 0xDD, 0xE3              ; EX (SP),IX  → IX=0xBBAA, stack top=0x2211
    .db 0xDD, 0x7C              ; LD A,IXH
    cp  a, #0xBB
    jp  nz, test_fail
    .db 0xDD, 0x7D              ; LD A,IXL
    cp  a, #0xAA
    jp  nz, test_fail
    .db 0xDD, 0xE1              ; POP IX  (restore IX=0x2211)
    .db 0xDD, 0x7C
    cp  a, #0x22
    jp  nz, test_fail

    ; EX (SP),IY
    ld  sp, #0x8FFE
    .db 0xFD, 0x21, 0xCC, 0xDD  ; LD IY,0xDDCC
    .db 0xFD, 0xE5              ; PUSH IY  → stack top = 0xDDCC
    .db 0xFD, 0x21, 0x33, 0x44  ; LD IY,0x4433
    .db 0xFD, 0xE3              ; EX (SP),IY → IY=0xDDCC, stack top=0x4433
    .db 0xFD, 0x7C              ; LD A,IYH
    cp  a, #0xDD
    jp  nz, test_fail
    .db 0xFD, 0x7D
    cp  a, #0xCC
    jp  nz, test_fail
    .db 0xFD, 0xE1              ; restore

    ; Restore safe SP before finishing
    ld  sp, #0xFFFF

    jp  test_pass

test_pass:
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt

test_fail:
    ld  a, #0x02
    out (_sim_ctl_port), a
    halt
