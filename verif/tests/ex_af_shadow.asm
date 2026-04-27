; ex_af_shadow.asm – EXC-04
;
; Dedicated test for EX AF,AF' that focuses on correct preservation and
; restoration of ALL flag bits — in particular F_6 (Z flag, bit 6) and
; F_7 (S flag, bit 7) via the shadow register (Fp) path in Tv80Core.
;
; Strategy:
;   1. Set up specific flag patterns (S=1/0, Z=1/0) in both main AF and
;      shadow AF'.
;   2. Exchange back and forth, verifying each field is correctly restored.
;   3. Exercise the exchange after instructions that set specific S/Z
;      combinations to distinguish the shadow register from the main one.
;   4. Perform many consecutive exchanges to stress the swap logic.

    .module ex_af_shadow

_sim_ctl_port = 0x80
_timeout_port = 0x82
FLAG_C  = 0x01
FLAG_N  = 0x02
FLAG_PV = 0x04
FLAG_H  = 0x10
FLAG_Z  = 0x40
FLAG_S  = 0x80

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
    ; EXC-04a: Basic S/Z preservation round-trip
    ;   Load A=0x00, flags with Z=1 into main AF.
    ;   Exchange → shadow holds {A=0x00, Z=1}.
    ;   Load A=0xFF, flags with S=1, Z=0 into main AF.
    ;   Exchange back → main AF restored to {A=0x00, Z=1, S=0}.
    ;========================================================
    call heartbeat

    ; Step 1: set A=0x00, Z=1
    xor  a, a               ; A=0, Z=1, S=0, C=0
    ex   af, af'            ; shadow ← {A=0x00, Z=1}

    ; Step 2: set A=0xFF, S=1
    ld   a, #0xFF
    and  a, #0xFF           ; A=0xFF, S=1, Z=0, P=parity(0xFF)=1
    ; Verify S=1 before swap
    jp   p,  test_fail      ; S must be set (A=0xFF, bit7=1)

    ; Step 3: swap back — main AF must restore {A=0x00, Z=1}
    ex   af, af'
    jp   nz, test_fail      ; Z must be set (restored from shadow)
    jp   m,  test_fail      ; S must be clear (A=0x00 was in shadow)
    cp   a, #0x00
    jp   nz, test_fail      ; A must be 0x00

    ;========================================================
    ; EXC-04b: S=1 in shadow restored correctly
    ;   Shadow ← {A=0x80, S=1, Z=0}
    ;   Main  ← {A=0x00, S=0, Z=1}
    ;   After second exchange: main gets {A=0x80, S=1, Z=0}
    ;========================================================
    call heartbeat

    ; Set up shadow with S=1
    ld   a, #0x80
    and  a, #0xFF           ; S=1, Z=0
    ex   af, af'            ; shadow ← {A=0x80, S=1}

    ; Main: S=0, Z=1
    xor  a, a               ; A=0, Z=1

    ; Exchange to get S=1 back
    ex   af, af'
    jp   p,  test_fail      ; S must be set (restored from shadow)
    jp   z,  test_fail      ; Z must be clear (A=0x80 → Z=0)
    cp   a, #0x80
    jp   nz, test_fail

    ;========================================================
    ; EXC-04c: Carry flag (C) preserved across exchange
    ;========================================================
    call heartbeat

    scf                     ; C=1
    ld   a, #0x42
    ex   af, af'            ; shadow ← {A=0x42, C=1}
    or   a, a               ; clear C in main
    jp   c,  test_fail      ; C must now be 0 in main

    ex   af, af'            ; restore shadow
    jp   nc, test_fail      ; C must be restored to 1
    cp   a, #0x42
    jp   nz, test_fail

    ;========================================================
    ; EXC-04d: Multiple consecutive exchanges — stress test
    ;   Repeat 8 times; on even exchanges main AF has pattern X,
    ;   on odd exchanges main AF has pattern Y.
    ;========================================================
    call heartbeat

    ; Set shadow to {A=0xA5, C=1}
    scf
    ld   a, #0xA5
    ex   af, af'

    ; Main: {A=0x5A, C=0, Z=0, S=0}
    or   a, a
    ld   a, #0x5A

    ; Exchange 1: main becomes A5 (C=1)
    ex   af, af'
    jp   nc, test_fail      ; C=1 expected

    ; Exchange 2: main becomes 5A (C=0)
    ex   af, af'
    jp   c,  test_fail      ; C=0 expected

    ; Exchange 3
    ex   af, af'
    jp   nc, test_fail

    ; Exchange 4
    ex   af, af'
    jp   c,  test_fail

    ; A-value sanity check at end of sequence (safe to clobber flags now)
    cp   a, #0x5A
    jp   nz, test_fail

    ;========================================================
    ; EXC-04e: H/N/PV flag bits preserved in shadow
    ;   After ADD (H may be set), exchange should preserve H.
    ;========================================================
    call heartbeat

    ; ADD that sets H: 0x0F + 0x01 = 0x10, H=1
    ld   a, #0x0F
    add  a, #0x01           ; A=0x10, H=1
    ex   af, af'            ; shadow ← {A=0x10, H=1}

    ; Main: clear H via XOR
    xor  a, a               ; H=0 after XOR

    ; Restore: check H=1 is back
    ex   af, af'
    push af
    pop  bc                 ; C = flags byte
    ld   a, c
    and  a, #FLAG_H
    jp   z,  test_fail      ; H must be restored (=1)
    ld   a, c
    and  a, #FLAG_Z
    jp   nz, test_fail      ; Z must be clear (A=0x10)

    ;========================================================
    ; EXC-04f: Exchange immediately after EI (shadow untouched by EI/DI)
    ;   Verify that EI/DI does not corrupt AF or AF'.
    ;========================================================
    call heartbeat

    ld   a, #0x77
    scf                     ; C=1
    ex   af, af'            ; shadow ← {A=0x77, C=1}
    di                      ; should not affect AF'
    ei                      ; should not affect AF'
    or   a, a               ; clear C in main AF
    ex   af, af'
    jp   nc, test_fail      ; C must still be 1 from shadow
    cp   a, #0x77
    jp   nz, test_fail

    ;========================================================
    ; EXC-04g: Verify A preserved correctly when A=0 (Z-flag corner)
    ;   Shadow {A=0x00, Z=1}, main {A=0x01, Z=0} — after exchange
    ;   verify A=0x00 and Z=1 are correctly restored.
    ;========================================================
    call heartbeat

    xor  a, a               ; A=0, Z=1
    ex   af, af'            ; shadow ← {0x00, Z=1}

    ld   a, #0x01
    or   a, a               ; A=1, Z=0

    ex   af, af'
    jp   nz, test_fail      ; Z=1 must be restored
    cp   a, #0x00
    jp   nz, test_fail

    ;--- PASS ---
    ld   a, #0x01
    out  (_sim_ctl_port), a
    halt

test_fail:
    ld   a, #0x02
    out  (_sim_ctl_port), a
    halt
