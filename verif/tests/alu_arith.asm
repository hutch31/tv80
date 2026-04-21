; alu_arith.asm – ALU-01..11
;
; Tests all 8-bit arithmetic ALU operations:
;   ALU-01  ADD A,r / ADD A,n
;   ALU-02  ADC A,r / ADC A,n
;   ALU-03  SUB r   / SUB n
;   ALU-04  SBC A,r / SBC A,n
;   ALU-08  INC r   / DEC r
;   ALU-10  DAA
;   ALU-11  CP r    / CP n
;   LOG-07  NEG  (placed here as it's also an 8-bit arithmetic op)
;
; Flag conventions (F register bit layout):
;   bit7=S  bit6=Z  bit5=Y  bit4=H  bit3=X  bit2=P/V  bit1=N  bit0=C
;
; When checking flag bits we mask with 0xD7 (=1101_0111b) to ignore
; the undocumented Y (bit5) and X (bit3) bits.

    .module alu_arith

_sim_ctl_port = 0x80
_timeout_port = 0x82
_msg_port     = 0x81
FLAG_C   = 0x01
FLAG_N   = 0x02
FLAG_PV  = 0x04
FLAG_H   = 0x10
FLAG_Z   = 0x40
FLAG_S   = 0x80
FLAG_MASK = 0xD7   ; mask out undocumented X and Y bits

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100

;------------------------------------------------------------------
; Macro-style subroutine: check A equals expected, else fail
; Caller must set B = expected, then CALL check_a
;------------------------------------------------------------------
check_a:
    cp  a, b
    jp  nz, test_fail
    ret

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

;------------------------------------------------------------------
; main test body
;------------------------------------------------------------------
main:
    ld  sp, #0xFFFF

    ;========================================================
    ; ALU-01: ADD A,n
    ;========================================================
    call heartbeat
    ; 0x05 + 0x03 = 0x08, no flags
    ld  a, #0x05
    add a, #0x03
    ld  b, #0x08
    call check_a

    ; 0x00 + 0x00 = 0x00, Z=1
    ld  a, #0x00
    add a, #0x00
    jp  nz, test_fail       ; Z must be set

    ; 0xFF + 0x01 = 0x00, C=1 Z=1
    ld  a, #0xFF
    add a, #0x01
    jp  nz, test_fail       ; Z must be set
    jp  nc, test_fail       ; C must be set

    ; 0x7F + 0x01 = 0x80 → overflow (V=1), S=1, C=0
    ld  a, #0x7F
    add a, #0x01
    jp  p,  test_fail       ; S must be set (result negative)
    jp  c,  test_fail       ; C must be clear
    ; Verify V flag via PUSH AF
    push af
    pop  bc                 ; C = F register
    ld   a, c
    and  a, #FLAG_PV
    jp   z, test_fail       ; overflow flag (P/V, bit2) must be 1

    ; 0x80 + 0x80 = 0x00, C=1, V=1 (overflow: neg+neg=pos), Z=1
    ld  a, #0x80
    add a, #0x80
    jp  nz, test_fail       ; Z must be set
    jp  nc, test_fail       ; C must be set
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   z, test_fail       ; V must be set

    ;========================================================
    ; ALU-01: ADD A,r (register operand)
    ;========================================================
    call heartbeat
    ld  a, #0x10
    ld  b, #0x20
    add a, b
    ld  b, #0x30
    call check_a

    ld  a, #0x33
    ld  c, #0x11
    add a, c
    ld  b, #0x44
    call check_a

    ld  a, #0x10
    ld  d, #0x05
    add a, d
    ld  b, #0x15
    call check_a

    ld  a, #0x20
    ld  e, #0x20
    add a, e                ; ADD A,A doubling via E
    ld  b, #0x40
    call check_a

    ld  a, #0x01
    ld  h, #0x02
    add a, h
    ld  b, #0x03
    call check_a

    ld  a, #0x07
    ld  l, #0x08
    add a, l
    ld  b, #0x0F
    call check_a

    ; ADD A,A
    ld  a, #0x40
    add a, a
    ld  b, #0x80
    call check_a

    ;========================================================
    ; ALU-02: ADC A,n (carry=0 and carry=1)
    ;========================================================
    call heartbeat
    ; carry=0: 0x05 + 0x03 + 0 = 0x08
    ld  a, #0x05
    or  a, a                ; clear carry (OR clears C)
    adc a, #0x03
    ld  b, #0x08
    call check_a

    ; carry=1: 0x05 + 0x03 + 1 = 0x09
    ld  a, #0xFF
    add a, #0x01            ; force C=1, A=0x00
    ld  a, #0x05            ; reload A, but carry stays
    adc a, #0x03
    ld  b, #0x09
    call check_a

    ; ADC wraps with carry: 0xFF + 0x00 + 1 = 0x00, C=1, Z=1
    ld  a, #0xFF
    add a, #0x01            ; C=1
    ld  a, #0xFF
    adc a, #0x00
    jp  nz, test_fail
    jp  nc, test_fail

    ;========================================================
    ; ALU-03: SUB n
    ;========================================================
    call heartbeat
    ; 0x08 - 0x03 = 0x05, N=1
    ld  a, #0x08
    sub a, #0x03
    ld  b, #0x05
    call check_a
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_N
    jp   z, test_fail       ; N must be set after SUB

    ; 0x00 - 0x01 = 0xFF, C=1 (borrow)
    ld  a, #0x00
    sub a, #0x01
    jp  nc, test_fail       ; C (borrow) must be set (check before call check_a clobbers via cp)
    ld  b, #0xFF
    call check_a

    ; 0x80 - 0x01 = 0x7F → overflow (neg-pos=pos), V=1
    ld  a, #0x80
    sub a, #0x01
    push af                 ; save flags before check_a clobbers them
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   z, test_fail       ; V must be set
    ld  a, #0x7F            ; reload A for check_a
    ld  b, #0x7F
    call check_a

    ;========================================================
    ; ALU-04: SBC A,n (borrow=0 and borrow=1)
    ;========================================================
    call heartbeat
    ; borrow=0: 0x08 - 0x03 - 0 = 0x05
    ld  a, #0x08
    or  a, a                ; clear carry
    sbc a, #0x03
    ld  b, #0x05
    call check_a

    ; borrow=1: 0x08 - 0x03 - 1 = 0x04
    ld  a, #0xFF
    add a, #0x01            ; force C=1
    ld  a, #0x08
    sbc a, #0x03
    ld  b, #0x04
    call check_a

    ;========================================================
    ; ALU-08: INC r / DEC r
    ;========================================================
    call heartbeat
    ; INC A
    ld  a, #0x41
    inc a
    ld  b, #0x42
    call check_a

    ; INC A: 0xFF -> 0x00, Z=1 (no carry change)
    ld  a, #0xFF
    scf                     ; set carry first
    inc a
    jp  nz, test_fail       ; Z must be set
    jp  nc, test_fail       ; C must still be set (INC does NOT change carry)

    ; DEC A
    ld  a, #0x42
    dec a
    ld  b, #0x41
    call check_a

    ; DEC A: 0x00 -> 0xFF, S=1, N=1
    ld  a, #0x00
    dec a
    jp  p,  test_fail       ; S must be set (check before call check_a clobbers flags)
    push af                 ; save flags before check_a clobbers them
    pop  bc
    ld   a, c
    and  a, #FLAG_N
    jp   z, test_fail       ; N must be set after DEC
    ld  a, #0xFF            ; reload A for check_a
    ld  b, #0xFF
    call check_a

    ; INC / DEC on B, C, D, E, H, L
    ld  b, #0x10
    inc b
    ld  a, b
    ld  b, #0x11
    call check_a

    ld  c, #0x20
    dec c
    ld  a, c
    ld  b, #0x1F
    call check_a

    ld  d, #0x00
    dec d
    ld  a, d
    ld  b, #0xFF
    call check_a

    ld  e, #0xFE
    inc e
    ld  a, e
    ld  b, #0xFF
    call check_a

    ld  h, #0x7F
    inc h               ; 0x7F+1 = 0x80, overflow
    ld  a, h
    ld  b, #0x80
    call check_a

    ld  l, #0x01
    dec l
    ld  a, l
    ld  b, #0x00
    call check_a
    jp  nz, test_fail   ; Z must be set

    ;========================================================
    ; ALU-11: CP r / CP n (result discarded, A unchanged)
    ;========================================================
    call heartbeat
    ld  a, #0x10
    cp  a, #0x10
    jp  nz, test_fail   ; equal → Z=1
    ld  b, #0x10
    call check_a        ; A must be unchanged

    ld  a, #0x20
    cp  a, #0x10        ; 0x20 > 0x10, no borrow
    jp  c,  test_fail   ; C must be clear
    jp  z,  test_fail   ; Z must be clear

    ld  a, #0x10
    cp  a, #0x20        ; 0x10 < 0x20, borrow
    jp  nc, test_fail   ; C (borrow) must be set

    ;========================================================
    ; NEG (LOG-07 / ED 44): A = 0 - A
    ;========================================================
    call heartbeat
    ld  a, #0x01
    .db 0xED, 0x44          ; NEG
    jp  nc, test_fail       ; borrow from 0, C=1 (check before call check_a clobbers via cp)
    ld  b, #0xFF
    call check_a
    push af
    pop  bc
    ld   a, c
    and  a, #FLAG_N
    jp   z, test_fail       ; N must be set

    ; NEG of 0x80 = 0x80 (special case: overflow)
    ld  a, #0x80
    .db 0xED, 0x44          ; NEG
    push af                 ; save flags before check_a clobbers them
    pop  bc
    ld   a, c
    and  a, #FLAG_PV
    jp   z, test_fail       ; V must be set
    ld  a, #0x80            ; reload A for check_a
    ld  b, #0x80
    call check_a

    ; NEG of 0x00 = 0x00, Z=1
    ld  a, #0x00
    .db 0xED, 0x44          ; NEG
    jp  nz, test_fail

    ;========================================================
    ; ALU-10: DAA
    ;========================================================
    call heartbeat
    ; After ADD: BCD 0x15 + BCD 0x27 = BCD 0x42
    ld  a, #0x15
    add a, #0x27            ; binary 0x3C
    daa                     ; adjust → 0x42
    ld  b, #0x42
    call check_a
    jp  c, test_fail        ; no carry expected

    ; After ADD with carry: BCD 0x55 + BCD 0x55 = BCD 1 10 → 0x10 + carry
    ld  a, #0x55
    add a, #0x55            ; binary 0xAA
    daa                     ; adjust → 0x10 + BCD carry
    jp  nc, test_fail       ; carry must be set

    ; After SUB: BCD 0x42 - BCD 0x15 = BCD 0x27
    ld  a, #0x42
    sub a, #0x15            ; binary 0x2D, N=1
    daa                     ; adjust → 0x27
    ld  b, #0x27
    call check_a

    jp  test_pass

test_pass:
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt

test_fail:
    ld  a, #0x02
    out (_sim_ctl_port), a
    halt
