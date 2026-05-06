; daa_ops.asm – comprehensive DAA instruction test
;
; Tests the DAA (Decimal Adjust Accumulator) instruction focusing on:
;   - P/V flag (parity) after DAA
;   - S (sign) flag after DAA
;   - Z (zero) flag after DAA
;   - N flag preservation (unchanged by DAA)
;   - Both correction nibbles applied simultaneously
;   - C=1 carry-in path from ADD/ADC overflow
;   - ADC with incoming carry
;   - SBC with borrow
;   - Multi-step BCD addition chain
;   - Edge cases: 00+00=0, 99-99=0
;
; Complements daa_carry.asm which covers the carry/half-carry correction paths.
;
; Z80 DAA algorithm:
;   After ADD/ADC (N=0):
;     if C=1 or A > 0x99  : corr |= 0x60, C_out=1
;     if H=1 or A[3:0] > 9: corr |= 0x06
;     A += corr
;   After SUB/SBC (N=1):
;     if C=1               : corr |= 0x60, C_out=1
;     if H=1               : corr |= 0x06
;     A -= corr
;
; Flag bit layout: S=7 Z=6 Y=5 H=4 X=3 P=2 N=1 C=0
; FLAG_MASK masks undocumented bits 5 and 3.

    .module daa_ops

_sim_ctl_port = 0x80
_timeout_port = 0x82

FLAG_C    = 0x01
FLAG_N    = 0x02
FLAG_P    = 0x04
FLAG_Z    = 0x40
FLAG_S    = 0x80
FLAG_MASK = 0xD7        ; mask out undocumented bits 5 (Y) and 3 (X)

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100

;------------------------------------------------------------------
; heartbeat: reset the timeout counter
;------------------------------------------------------------------
heartbeat:
    push af
    ld   a, #0x02
    out  (_timeout_port), a
    ld   a, #0x01
    out  (_timeout_port), a
    pop  af
    ret

;------------------------------------------------------------------
; check_a: compare A with B; jump to test_fail if not equal
;------------------------------------------------------------------
check_a:
    cp  a, b
    jp  nz, test_fail
    ret

;------------------------------------------------------------------
; main
;------------------------------------------------------------------
main:
    ld  sp, #0xFFFF

    ;========================================================
    ; Case 1: ADD — no correction, P/V=0 (odd parity).
    ;   BCD: 23 + 14 = 37
    ;   0x23 + 0x14 = 0x37, no correction needed.
    ;   0x37 = 0011 0111 → 5 ones → odd parity → P=0
    ;========================================================
    call heartbeat
    ld   a, #0x23
    add  a, #0x14           ; 0x37, H=0, C=0, upper 3 ≤ 9, lower 7 ≤ 9
    daa                     ; no correction
    push af
    pop  hl                 ; H=A, L=F
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x37
    call check_a
    ld   a, l
    and  a, #FLAG_P
    jp   nz, test_fail      ; P must be 0 (odd parity)

    ;========================================================
    ; Case 2: ADD — lower correction (+0x06), P/V=1 (even parity).
    ;   BCD: 09 + 03 = 12
    ;   0x09 + 0x03 = 0x0C, lower nibble C > 9 → +0x06 → 0x12
    ;   0x12 = 0001 0010 → 2 ones → even parity → P=1
    ;========================================================
    call heartbeat
    ld   a, #0x09
    add  a, #0x03           ; 0x0C, lower C > 9
    daa                     ; +0x06 → 0x12
    push af
    pop  hl                 ; H=A, L=F
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x12
    call check_a
    ld   a, l
    and  a, #FLAG_P
    jp   z,  test_fail      ; P must be 1 (even parity)

    ;========================================================
    ; Case 3: ADD — S flag set (result ≥ 0x80, no correction needed).
    ;   BCD: 50 + 35 = 85
    ;   0x50 + 0x35 = 0x85, neither nibble > 9, no carry → no correction
    ;   0x85 has bit 7 set → S=1
    ;========================================================
    call heartbeat
    ld   a, #0x50
    add  a, #0x35           ; 0x85, H=0, C=0, upper 8 ≤ 9, lower 5 ≤ 9
    daa                     ; no correction
    push af
    pop  hl                 ; H=A, L=F
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x85
    call check_a
    ld   a, l
    and  a, #FLAG_S
    jp   z,  test_fail      ; S must be 1

    ;========================================================
    ; Case 4: ADD — Z flag set, C=1 (result wraps to 0x00).
    ;   BCD: 55 + 45 = 100
    ;   0x55 + 0x45 = 0x9A, lower A > 9 → +0x06 → 0xA0 → upper > 9 → +0x60 → 0x00
    ;   Z=1, C=1
    ;========================================================
    call heartbeat
    ld   a, #0x55
    add  a, #0x45           ; 0x9A, lower A > 9
    daa                     ; +0x06 → 0xA0; +0x60 → 0x00, C=1
    push af
    pop  hl                 ; H=A, L=F
    jp   nc, test_fail      ; C must be set
    ld   b, #0x00
    call check_a
    ld   a, l
    and  a, #FLAG_Z
    jp   z,  test_fail      ; Z must be 1

    ;========================================================
    ; Case 5: ADD — N flag preserved as 0 after DAA.
    ;   BCD: 23 + 14 = 37 (reuse the no-correction case)
    ;   After ADD, N=0; after DAA, N must still be 0.
    ;========================================================
    call heartbeat
    ld   a, #0x23
    add  a, #0x14           ; N=0 after ADD
    daa
    push af
    pop  hl                 ; L=F
    ld   a, l
    and  a, #FLAG_N
    jp   nz, test_fail      ; N must remain 0

    ;========================================================
    ; Case 6: SUB — N flag preserved as 1 after DAA.
    ;   BCD: 76 - 43 = 33
    ;   0x76 - 0x43 = 0x33, no correction needed.
    ;   After SUB, N=1; after DAA, N must still be 1.
    ;========================================================
    call heartbeat
    ld   a, #0x76
    sub  a, #0x43           ; 0x33, N=1, H=0, C=0
    daa                     ; no correction
    push af
    pop  hl                 ; L=F
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x33
    call check_a
    ld   a, l
    and  a, #FLAG_N
    jp   z,  test_fail      ; N must remain 1

    ;========================================================
    ; Case 7: ADD — both corrections (A > 0x99, H=1).
    ;   BCD: 68 + 38 = 106
    ;   0x68 + 0x38 = 0xA0, H=1 (8+8=16 overflows nibble)
    ;   C=0, A=0xA0 > 0x99 → +0x60; H=1 → +0x06 → total +0x66
    ;   0xA0 + 0x66 = 0x106 → A=0x06, C=1
    ;========================================================
    call heartbeat
    ld   a, #0x68
    add  a, #0x38           ; 0xA0, H=1
    daa                     ; +0x66 → 0x06, C=1
    jp   nc, test_fail      ; C must be set
    ld   b, #0x06
    call check_a

    ;========================================================
    ; Case 8: ADD — C=1 carry-in, both corrections.
    ;   BCD: 99 + 99 = 198
    ;   0x99 + 0x99 = 0x132 → A=0x32, C=1, H=1
    ;   C=1 → +0x60; H=1 → +0x06 → 0x32+0x66=0x98, C=1
    ;========================================================
    call heartbeat
    ld   a, #0x99
    add  a, #0x99           ; 0x32, C=1, H=1
    daa                     ; +0x66 → 0x98, C=1
    jp   nc, test_fail      ; C must be set
    ld   b, #0x98
    call check_a

    ;========================================================
    ; Case 9: ADC — carry-in bit included in addition.
    ;   BCD: 35 + 48 + 1 (carry) = 84
    ;   0x35 + 0x48 + 1 = 0x7E, lower E > 9 → +0x06 → 0x84, C=0
    ;========================================================
    call heartbeat
    scf
    ld   a, #0x35
    adc  a, #0x48           ; 0x35 + 0x48 + 1 = 0x7E, lower E > 9
    daa                     ; +0x06 → 0x84, C=0
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x84
    call check_a

    ;========================================================
    ; Case 10: SUB — H=1 half-borrow, lower correction (−0x06).
    ;   BCD: 30 - 01 = 29
    ;   0x30 - 0x01 = 0x2F, N=1, H=1 (0 − 1 borrows from upper nibble)
    ;   H=1 → subtract 0x06 → 0x29, C=0
    ;========================================================
    call heartbeat
    ld   a, #0x30
    sub  a, #0x01           ; 0x2F, N=1, H=1
    daa                     ; −0x06 → 0x29
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x29
    call check_a

    ;========================================================
    ; Case 11: SUB — C=1 borrow, upper correction only (−0x60).
    ;   BCD: 20 - 30 → BCD result = 90 with borrow
    ;   0x20 - 0x30 = 0xF0, C=1, H=0
    ;   C=1 → subtract 0x60 → 0xF0 − 0x60 = 0x90, C=1
    ;========================================================
    call heartbeat
    ld   a, #0x20
    sub  a, #0x30           ; 0xF0, N=1, C=1, H=0
    daa                     ; −0x60 → 0x90, C=1
    jp   nc, test_fail      ; C must remain set
    ld   b, #0x90
    call check_a

    ;========================================================
    ; Case 12: SUB — C=1 and H=1, both corrections (−0x66).
    ;   BCD: 00 - 01 → BCD result = 99 with borrow
    ;   0x00 - 0x01 = 0xFF, C=1, H=1
    ;   C=1 → −0x60; H=1 → −0x06 → 0xFF − 0x66 = 0x99, C=1
    ;========================================================
    call heartbeat
    ld   a, #0x00
    sub  a, #0x01           ; 0xFF, N=1, C=1, H=1
    daa                     ; −0x66 → 0x99, C=1
    jp   nc, test_fail      ; C must remain set
    ld   b, #0x99
    call check_a

    ;========================================================
    ; Case 13: SBC — subtract with incoming borrow C=1.
    ;   BCD: 50 - 25 - 1 (borrow) = 24
    ;   0x50 - 0x25 - 1 = 0x2A, H=1 (0 − 5 − 1 borrows)
    ;   H=1 → subtract 0x06 → 0x24, C=0
    ;========================================================
    call heartbeat
    scf
    ld   a, #0x50
    sbc  a, #0x25           ; 0x50 − 0x25 − 1 = 0x2A, N=1, H=1
    daa                     ; −0x06 → 0x24
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x24
    call check_a

    ;========================================================
    ; Case 14: Edge case — 00 + 00 = 00 (Z=1, C=0).
    ;   No correction needed; result is zero.
    ;========================================================
    call heartbeat
    ld   a, #0x00
    add  a, #0x00           ; 0x00, no flags set
    daa                     ; no correction
    push af
    pop  hl
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x00
    call check_a
    ld   a, l
    and  a, #FLAG_Z
    jp   z,  test_fail      ; Z must be 1

    ;========================================================
    ; Case 15: Edge case — 99 - 99 = 00 (Z=1, C=0).
    ;   0x99 - 0x99 = 0x00, N=1, H=0, C=0; no correction needed.
    ;   Result is zero: Z=1.
    ;========================================================
    call heartbeat
    ld   a, #0x99
    sub  a, #0x99           ; 0x00, N=1, H=0, C=0
    daa                     ; no correction
    push af
    pop  hl
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x00
    call check_a
    ld   a, l
    and  a, #FLAG_Z
    jp   z,  test_fail      ; Z must be 1

    ;========================================================
    ; Case 16: Multi-step BCD chain.
    ;   Step 1: BCD 12 + 34 = 46  →  0x12 + 0x34 = 0x46, no correction
    ;   Step 2: BCD 46 + 56 = 102 →  0x46 + 0x56 = 0x9C, lower C > 9 → +0x06 → 0xA2
    ;                                 0xA2 > 0x99 → +0x60 → 0x02, C=1
    ;   Verify chain: A=0x02, C=1
    ;========================================================
    call heartbeat
    ld   a, #0x12
    add  a, #0x34           ; step 1: 0x46
    daa
    jp   c, test_fail       ; C must be clear after step 1
    ld   b, #0x46
    call check_a

    ld   a, #0x46
    add  a, #0x56           ; step 2: 0x9C, lower C > 9
    daa                     ; +0x06 → 0xA2; +0x60 → 0x02, C=1
    jp   nc, test_fail      ; C must be set after step 2
    ld   b, #0x02
    call check_a

    ;--- PASS ---
    ld   a, #0x01
    out  (_sim_ctl_port), a
    halt

test_fail:
    ld   a, #0x02
    out  (_sim_ctl_port), a
    halt
