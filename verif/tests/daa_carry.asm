; daa_carry.asm – ALU-12
;
; Tests DAA (Decimal Adjust Accumulator) with all significant carry and
; half-carry combinations, targeting both the daaQ0 (pass-through) and
; daaQ1 (correction-needed) ALU code paths.
;
; Z80 DAA algorithm (simplified):
;   After addition (N=0):
;     if C=1 or A[7:4] > 9 : add 0x60 to A, set C
;     if H=1 or A[3:0] > 9 : add 0x06 to A
;   After subtraction (N=1):
;     if C=1 : subtract 0x60 from A, C stays 1
;     if H=1 : subtract 0x06 from A
;
; Flag bit layout: S=7 Z=6 Y=5 H=4 X=3 P=2 N=1 C=0

    .module daa_carry

_sim_ctl_port = 0x80
_timeout_port = 0x82
FLAG_C   = 0x01
FLAG_Z   = 0x40

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
    ; Case 1: ADD — result already in BCD range; no correction.
    ;   0x12 + 0x13 = 0x25 → DAA → 0x25, C=0
    ;   (exercises daaQ0 pass-through path)
    ;========================================================
    call heartbeat
    ld   a, #0x12
    add  a, #0x13           ; 0x25, H=0, C=0, lower nibble 5 <= 9
    daa                     ; no correction → A stays 0x25
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x25
    call check_a

    ;========================================================
    ; Case 2: ADD — lower digit > 9 → lower nibble correction (+6).
    ;   0x08 + 0x04 = 0x0C → DAA → 0x12, C=0
    ;========================================================
    call heartbeat
    ld   a, #0x08
    add  a, #0x04           ; 0x0C, lower nibble 0xC > 9
    daa                     ; add 0x06 → 0x12
    jp   c,  test_fail      ; C must be clear
    ld   b, #0x12
    call check_a

    ;========================================================
    ; Case 3: ADD — half-carry set (H=1) → lower nibble correction.
    ;   0x19 + 0x01 = 0x1A, H=1 → DAA → 0x20
    ;========================================================
    call heartbeat
    ld   a, #0x19
    add  a, #0x01           ; 0x1A, H=1 (carry out of bit 3)
    daa                     ; H=1 → add 0x06 → 0x20
    jp   c,  test_fail
    ld   b, #0x20
    call check_a

    ;========================================================
    ; Case 4: ADD — upper digit > 9 → upper correction, C=1.
    ;   0x90 + 0x15 = 0xA5 → DAA → 0x05, C=1
    ;   (exercises daaQ1 upper-nibble correction path)
    ;========================================================
    call heartbeat
    ld   a, #0x90
    add  a, #0x15           ; 0xA5, C=0, upper nibble 0xA > 9
    daa                     ; add 0x60 → 0x05, C=1
    jp   nc, test_fail      ; C must be set
    ld   b, #0x05
    call check_a

    ;========================================================
    ; Case 5: ADD — both corrections needed + Z=1.
    ;   0x99 + 0x01 = 0x9A → lower correction → 0xA0 → upper correction
    ;   → 0x00, C=1, Z=1
    ;========================================================
    call heartbeat
    ld   a, #0x99
    add  a, #0x01           ; 0x9A, lower A > 9
    daa                     ; lower: +0x06 → 0xA0; upper: +0x60 → 0x00, C=1
    jp   nz, test_fail      ; Z must be set
    jp   nc, test_fail      ; C must be set
    ld   b, #0x00
    call check_a

    ;========================================================
    ; Case 6: ADD — carry propagated from previous operation.
    ;   0x55 + 0x55 = 0xAA (upper nibble 0xA > 9) → DAA → 0x10, C=1
    ;========================================================
    call heartbeat
    ld   a, #0x55
    add  a, #0x55           ; 0xAA, C=0
    daa                     ; upper: +0x60 → 0x0A; lower: A > 9 → +0x06 → 0x10, C=1
    jp   nc, test_fail      ; C must be set

    ;========================================================
    ; Case 7: SUB — result in BCD range; no correction needed.
    ;   0x35 − 0x13 = 0x22 → DAA → 0x22, C=0
    ;   (N=1 path, daaQ0 pass-through)
    ;========================================================
    call heartbeat
    ld   a, #0x35
    sub  a, #0x13           ; 0x22, N=1, H=0, C=0
    daa                     ; no correction → 0x22
    jp   c,  test_fail
    ld   b, #0x22
    call check_a

    ;========================================================
    ; Case 8: SUB — half-borrow (H=1) → lower nibble correction (−6).
    ;   0x20 − 0x01 = 0x1F, H=1 → DAA → 0x19
    ;========================================================
    call heartbeat
    ld   a, #0x20
    sub  a, #0x01           ; 0x1F, N=1, H=1
    daa                     ; H=1, N=1 → subtract 0x06 → 0x19
    jp   c,  test_fail
    ld   b, #0x19
    call check_a

    ;========================================================
    ; Case 9: SUB — borrow (C=1) → upper correction (−0x60), C stays 1.
    ;   0x00 − 0x01 = 0xFF, C=1, H=1 → DAA → 0x99, C=1
    ;========================================================
    call heartbeat
    ld   a, #0x00
    sub  a, #0x01           ; 0xFF, N=1, C=1, H=1
    daa                     ; C=1 → −0x60; H=1 → −0x06 → 0xFF−0x66=0x99, C=1
    jp   nc, test_fail      ; C must remain set
    ld   b, #0x99
    call check_a

    ;========================================================
    ; Case 10: ADC with carry — exercises C-in path for DAA.
    ;   0x58 + 0x46 + C=1 = 0x9F → DAA → 0x05 +carry? check…
    ;   0x58 + 0x46 = 0x9E, +1 = 0x9F; lower nibble F > 9 and upper > 9
    ;   → +0x06 → 0xA5; +0x60 → 0x05, C=1
    ;========================================================
    call heartbeat
    scf                     ; set carry
    ld   a, #0x58
    adc  a, #0x46           ; 0x58+0x46+1 = 0x9F, lower nibble F > 9
    daa                     ; lower: +6 → 0xA5; upper 0xA > 9: +0x60 → 0x05, C=1
    jp   nc, test_fail      ; C must be set
    ld   b, #0x05
    call check_a

    ;--- PASS ---
    ld   a, #0x01
    out  (_sim_ctl_port), a
    halt

test_fail:
    ld   a, #0x02
    out  (_sim_ctl_port), a
    halt
