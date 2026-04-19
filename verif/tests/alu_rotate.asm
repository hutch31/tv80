; alu_rotate.asm – ROT-01..05
;
; Tests all rotate and shift instructions:
;   ROT-01  RLCA / RRCA  (rotate A, C=bit rotated out, S/Z/P unchanged)
;   ROT-02  RLA  / RRA   (rotate A through carry)
;   ROT-03  RLC  / RRC   / RL / RR / SLA / SRA / SRL  (CB-prefix, on registers)
;   ROT-04  RLD  / RRD   (nibble rotation A ↔ (HL))
;   ROT-05  Rotate of (HL) via CB prefix

    .module alu_rotate

_sim_ctl_port = 0x80
FLAG_C   = 0x01
FLAG_Z   = 0x40
FLAG_S   = 0x80
FLAG_H   = 0x10
FLAG_N   = 0x02
FLAG_PV  = 0x04

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ;========================================================
    ; ROT-01: RLCA (rotate left circular accumulator)
    ;========================================================
    ; 0x80 → 0x01, C=1 (bit7 goes to C and bit0)
    ld  a, #0x80
    rlca
    cp  a, #0x01
    jp  nz, test_fail
    jp  nc, test_fail       ; C must be set

    ; 0x01 → 0x02, C=0
    ld  a, #0x01
    rlca
    cp  a, #0x02
    jp  nz, test_fail
    jp  c,  test_fail       ; C must be clear

    ; RLCA does NOT change S,Z,P/V: Z stays set from previous XOR A
    xor a, a                ; A=0x00, Z=1
    rlca                    ; A=0x00 → 0x00, C=0; Z unchanged (remains 1)
    jp  nz, test_fail       ; Z should still be 1 → NZ false → no jump → OK

    ;========================================================
    ; ROT-01: RRCA (rotate right circular accumulator)
    ;========================================================
    ; 0x01 → 0x80, C=1
    ld  a, #0x01
    rrca
    cp  a, #0x80
    jp  nz, test_fail
    jp  nc, test_fail       ; C must be set

    ; 0x80 → 0x40, C=0
    ld  a, #0x80
    rrca
    cp  a, #0x40
    jp  nz, test_fail
    jp  c,  test_fail

    ;========================================================
    ; ROT-02: RLA (rotate left through carry)
    ;========================================================
    ; C=0, A=0x80: bit7 → C, A=0x00, old_C → bit0 → A=0x00
    ld  a, #0x80
    or  a, a                ; clear carry
    rla
    cp  a, #0x00
    jp  nz, test_fail
    jp  nc, test_fail       ; C must be set (got bit7=1)

    ; C=1, A=0x00: A = 0x01 (old carry into bit0), new C=0
    ld  a, #0x80
    rla                     ; from previous: C=1, A=0x80 → result: A=0x01, C=1? Wait.
    ; Actually at this point C=1 (from previous RLA), A was just set to #0x80...
    ; Let me redo step by step:

    ; Step 1: clear carry, set A=0x40
    or  a, a                ; XOR trick: use OR to clear C
    ld  a, #0x40
    or  a, a                ; C=0 now (RLA or any arith clears it if no carry)
    ; Actually or a,a: does it clear carry? Yes: OR always clears C and H.
    rla                     ; C=0, A=0x40: A → 0x80, C=0 (bit7 was 0)
    cp  a, #0x80
    jp  nz, test_fail
    jp  c,  test_fail       ; C must be clear

    ; Step 2: C=0, A=0xFF: A → 0xFE, C=1
    ld  a, #0xFF
    or  a, a                ; C=0
    rla                     ; C=0 in, bit7=1 → C=1 out, A=0xFE+0=0xFE
    cp  a, #0xFE
    jp  nz, test_fail
    jp  nc, test_fail       ; C must be set

    ;========================================================
    ; ROT-02: RRA (rotate right through carry)
    ;========================================================
    ; C=0, A=0x01: A → 0x00, C=1 (bit0 into C)
    ld  a, #0x01
    or  a, a                ; C=0
    rra
    cp  a, #0x00
    jp  nz, test_fail
    jp  nc, test_fail       ; C=1

    ; C=1, A=0x00: A → 0x80 (old C into bit7), C=0
    rra                     ; C was 1 from previous
    cp  a, #0x80
    jp  nz, test_fail
    jp  c,  test_fail       ; C=0

    ;========================================================
    ; ROT-03: CB-prefix rotate/shift on registers
    ;========================================================
    ; RLC A (CB 07): 0x80 → 0x01, C=1
    ld  a, #0x80
    .db 0xCB, 0x07          ; RLC A
    cp  a, #0x01
    jp  nz, test_fail
    jp  nc, test_fail

    ; RRC A (CB 0F): 0x01 → 0x80, C=1
    ld  a, #0x01
    .db 0xCB, 0x0F          ; RRC A
    cp  a, #0x80
    jp  nz, test_fail
    jp  nc, test_fail

    ; RL A (CB 17): C=0, A=0x80 → A=0x00, C=1
    ld  a, #0x80
    or  a, a                ; C=0
    .db 0xCB, 0x17          ; RL A
    jp  nz, test_fail       ; Z must be set (A=0x00)
    jp  nc, test_fail       ; C must be set

    ; RR A (CB 1F): C=1, A=0x00 → A=0x80, C=0
    .db 0xCB, 0x1F          ; RR A (C was 1 from above)
    cp  a, #0x80
    jp  nz, test_fail
    jp  c,  test_fail       ; C must be clear

    ; SLA A (CB 27): 0x81 → 0x02, C=1 (shifts 0 into bit0)
    ld  a, #0x81
    .db 0xCB, 0x27          ; SLA A
    cp  a, #0x02
    jp  nz, test_fail
    jp  nc, test_fail       ; C=1 (bit7 was 1)

    ; SRA A (CB 2F): arithmetic shift right, sign bit preserved
    ; 0x80 → 0xC0, C=0 (bit0 was 0)
    ld  a, #0x80
    .db 0xCB, 0x2F          ; SRA A
    cp  a, #0xC0
    jp  nz, test_fail
    jp  c,  test_fail       ; C=0

    ; SRL A (CB 3F): logical shift right, 0 into bit7
    ; 0x81 → 0x40, C=1
    ld  a, #0x81
    .db 0xCB, 0x3F          ; SRL A
    cp  a, #0x40
    jp  nz, test_fail
    jp  nc, test_fail       ; C=1

    ; RLC B (CB 00): 0x80 → 0x01, C=1
    ld  b, #0x80
    .db 0xCB, 0x00          ; RLC B
    ld  a, b
    cp  a, #0x01
    jp  nz, test_fail

    ; RLC C (CB 01)
    ld  c, #0x80
    .db 0xCB, 0x01          ; RLC C
    ld  a, c
    cp  a, #0x01
    jp  nz, test_fail

    ; SRL D (CB 3A): 0xFF → 0x7F, C=1
    ld  d, #0xFF
    .db 0xCB, 0x3A          ; SRL D
    ld  a, d
    cp  a, #0x7F
    jp  nz, test_fail
    jp  nc, test_fail

    ;========================================================
    ; ROT-05: CB rotate on (HL)
    ;========================================================
    ; Place 0x80 in RAM, RLC (HL), verify (HL)=0x01, C=1
    ld  hl, #0x8000         ; RAM address
    ld  (hl), #0x80
    .db 0xCB, 0x06          ; RLC (HL)
    ld  a, (hl)
    cp  a, #0x01
    jp  nz, test_fail
    jp  nc, test_fail

    ; SRL (HL): (HL)=0x01 → 0x00, C=1, Z=1
    .db 0xCB, 0x3E          ; SRL (HL)
    ld  a, (hl)
    jp  nz, test_fail       ; A should be 0, Z=1
    jp  nc, test_fail       ; C=1

    ;========================================================
    ; ROT-04: RLD (ED 6F) and RRD (ED 67)
    ;========================================================
    ; RLD: high nibble of A → low nibble of A
    ;      low nibble of (HL) → high nibble of (HL)
    ;      old high nibble of (HL) → low nibble of A
    ; Set A=0x12, (HL)=0x34:
    ;   RLD: A → 0x13, (HL) → 0x42
    ld  hl, #0x8000
    ld  a, #0x12
    ld  (hl), #0x34
    .db 0xED, 0x6F          ; RLD
    cp  a, #0x13
    jp  nz, test_fail
    ld  a, (hl)
    cp  a, #0x42
    jp  nz, test_fail

    ; RRD: high nibble of (HL) → low nibble of A
    ;      low nibble of A → high nibble of (HL)
    ;      low nibble of (HL) → high nibble of (HL)
    ; After RLD: A=0x13, (HL)=0x42
    ; RRD: A → 0x12, (HL) → 0x31... let me recalculate:
    ; RRD: A[3:0]=3, (HL)[7:4]=4, (HL)[3:0]=2
    ;   result: A → A[7:4]=0x1, (HL)[3:0]=3 → A=0x13... hmm
    ; Actually RRD:
    ;   new_A  = (A  & 0xF0) | (HL)[3:0]
    ;   new_HL = ((HL) >> 4) | (A[3:0] << 4)
    ; A=0x13, (HL)=0x42:
    ;   new_A  = (0x10) | 0x02 = 0x12
    ;   new_HL = 0x04   | 0x30 = 0x34
    .db 0xED, 0x67          ; RRD
    cp  a, #0x12
    jp  nz, test_fail
    ld  a, (hl)
    cp  a, #0x34
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
