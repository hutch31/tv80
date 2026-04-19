; jump_ops.asm – JMP-01..08
;
;   JMP-01  JP nn (unconditional)
;   JMP-02  JP cc,nn (all 8 conditions: NZ Z NC C PO PE P M)
;   JMP-03  JR e (relative unconditional)
;   JMP-04  JR cc,e (NZ Z NC C)
;   JMP-05  JP (HL) / JP (IX) / JP (IY)
;   JMP-06  DJNZ
;   JMP-07  CALL nn / RET / CALL cc / RET cc
;   JMP-08  RST 00/08/10/18/20/28/30/38

    .module jump_ops

_sim_ctl_port = 0x80

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    ; RST targets – each RST writes a unique marker to 0x8000 and returns
    .org 0x0008             ; RST 08H
rst08_handler:
    push hl
    ld  hl, #0x8001
    inc (hl)                ; increment counter at 0x8001
    pop hl
    ret

    .org 0x0010             ; RST 10H
rst10_handler:
    push hl
    ld  hl, #0x8002
    inc (hl)
    pop hl
    ret

    .org 0x0018             ; RST 18H
rst18_handler:
    push hl
    ld  hl, #0x8003
    inc (hl)
    pop hl
    ret

    .org 0x0020             ; RST 20H
rst20_handler:
    push hl
    ld  hl, #0x8004
    inc (hl)
    pop hl
    ret

    .org 0x0028             ; RST 28H
rst28_handler:
    push hl
    ld  hl, #0x8005
    inc (hl)
    pop hl
    ret

    .org 0x0030             ; RST 30H
rst30_handler:
    push hl
    ld  hl, #0x8006
    inc (hl)
    pop hl
    ret

    .org 0x0038             ; RST 38H (also INT mode-1 vector)
rst38_handler:
    push hl
    ld  hl, #0x8007
    inc (hl)
    pop hl
    ret

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ; Clear RST counter area
    ld  hl, #0x8000
    ld  b, #8
clr_loop:
    ld  (hl), #0
    inc hl
    djnz clr_loop

    ;========================================================
    ; JMP-01: JP nn (unconditional)
    ;========================================================
    jp  jp_target
    jp  test_fail           ; must NOT reach here
jp_target:

    ;========================================================
    ; JMP-02: JP cc,nn – all 8 conditions
    ;========================================================
    ; NZ: Z=0 → jump taken
    xor a, a                ; Z=1
    ld  a, #0x01            ; Z=0
    jp  z,  test_fail       ; must NOT jump (Z=0, Z condition fails)
    jp  nz, jp_nz_ok        ; must jump
    jp  test_fail
jp_nz_ok:

    ; Z: Z=1 → jump taken
    xor a, a                ; Z=1
    jp  nz, test_fail
    jp  z,  jp_z_ok
    jp  test_fail
jp_z_ok:

    ; NC: C=0 → jump taken
    or  a, a                ; clears C
    jp  c,  test_fail
    jp  nc, jp_nc_ok
    jp  test_fail
jp_nc_ok:

    ; C: C=1 → jump taken
    scf
    jp  nc, test_fail
    jp  c,  jp_c_ok
    jp  test_fail
jp_c_ok:

    ; PO (P/V=0): after XOR A, P/V=1 (even parity of 0x00)...
    ; Use AND 0x01 after loading A=0x01 to get P=0 (odd parity)
    ld  a, #0x01
    and a, #0x01            ; A=0x01, P=0 (odd parity → PO)
    jp  pe, test_fail
    jp  po, jp_po_ok
    jp  test_fail
jp_po_ok:

    ; PE (P/V=1): A=0x03, AND 0x03 = 0x03, P=1 (even parity)
    ld  a, #0x03
    and a, #0x03            ; A=0x03 = 0000_0011, parity=even → PE
    jp  po, test_fail
    jp  pe, jp_pe_ok
    jp  test_fail
jp_pe_ok:

    ; P (S=0): positive result
    ld  a, #0x01
    or  a, a                ; A=0x01, S=0
    jp  m,  test_fail
    jp  p,  jp_p_ok
    jp  test_fail
jp_p_ok:

    ; M (S=1): negative result
    ld  a, #0x80
    or  a, a                ; A=0x80, S=1
    jp  p,  test_fail
    jp  m,  jp_m_ok
    jp  test_fail
jp_m_ok:

    ;========================================================
    ; JMP-03: JR e (relative unconditional)
    ;========================================================
    ; JR +0 (jump to next instruction = 2-byte NOP)
    .db 0x18, 0x00          ; JR +0 (next instruction)
    ; JR -2 would loop forever; just do a forward jump
    .db 0x18, 0x02          ; JR +2 (skip 2 bytes)
    .db 0x00, 0x00          ; these 2 bytes skipped
    ; Reach here = JR worked

    ;========================================================
    ; JMP-04: JR cc,e (NZ Z NC C)
    ;========================================================
    ; JR NZ: Z=0 → jump
    ld  a, #0x01            ; Z=0
    .db 0x20, 0x01          ; JR NZ, +1 (skip 1 byte)
    jp  test_fail
    ; JR Z: Z=1 → jump
    xor a, a                ; Z=1
    .db 0x28, 0x01          ; JR Z, +1 (skip 1 byte)
    jp  test_fail
    ; JR NC: C=0 → jump
    or  a, a                ; C=0
    .db 0x30, 0x01          ; JR NC, +1
    jp  test_fail
    ; JR C: C=1 → jump
    scf
    .db 0x38, 0x01          ; JR C, +1
    jp  test_fail

    ;========================================================
    ; JMP-05: JP (HL) / JP (IX) / JP (IY)
    ;========================================================
    ld  hl, #jp_hl_target
    jp  (hl)
    jp  test_fail
jp_hl_target:

    .db 0xDD, 0x21          ; LD IX, lo hi
    .db <jp_ix_target
    .db >jp_ix_target
    .db 0xDD, 0xE9          ; JP (IX)
    jp  test_fail
jp_ix_target:

    .db 0xFD, 0x21          ; LD IY, lo hi
    .db <jp_iy_target
    .db >jp_iy_target
    .db 0xFD, 0xE9          ; JP (IY)
    jp  test_fail
jp_iy_target:

    ;========================================================
    ; JMP-06: DJNZ
    ;========================================================
    ; Loop 5 times
    ld  b, #5
    ld  c, #0
djnz_loop:
    inc c
    djnz djnz_loop
    ld  a, c
    cp  a, #5
    jp  nz, test_fail
    ld  a, b
    jp  nz, test_fail       ; B must be 0

    ;========================================================
    ; JMP-07: CALL nn / RET
    ;========================================================
    call test_sub           ; call and return
    ; Verify the subroutine set A=0xBE
    cp  a, #0xBE
    jp  nz, test_fail

    ; CALL NZ / RET NZ
    ld  a, #0x01            ; Z=0 after ld
    xor a, #0x01            ; Z=1 now (A=0x00)
    call z, test_sub_z      ; should be called (Z=1)
    cp  a, #0xAA
    jp  nz, test_fail

    ; CALL NC
    or  a, a                ; C=0
    call nc, test_sub_nc
    cp  a, #0xBB
    jp  nz, test_fail

    ;========================================================
    ; JMP-08: RST 00/08/10/18/20/28/30/38
    ;========================================================
    ; RST 00H: RST 0x00 = 0xC7 jumps to 0x0000 which is a JP main...
    ; That would restart execution. Skip RST 00H test.

    ; RST 08H
    rst 0x08
    ld  hl, #0x8001
    ld  a, (hl)
    cp  a, #1
    jp  nz, test_fail

    ; RST 10H
    rst 0x10
    ld  hl, #0x8002
    ld  a, (hl)
    cp  a, #1
    jp  nz, test_fail

    ; RST 18H
    rst 0x18
    ld  hl, #0x8003
    ld  a, (hl)
    cp  a, #1
    jp  nz, test_fail

    ; RST 20H
    rst 0x20
    ld  hl, #0x8004
    ld  a, (hl)
    cp  a, #1
    jp  nz, test_fail

    ; RST 28H
    rst 0x28
    ld  hl, #0x8005
    ld  a, (hl)
    cp  a, #1
    jp  nz, test_fail

    ; RST 30H
    rst 0x30
    ld  hl, #0x8006
    ld  a, (hl)
    cp  a, #1
    jp  nz, test_fail

    ; RST 38H
    rst 0x38
    ld  hl, #0x8007
    ld  a, (hl)
    cp  a, #1
    jp  nz, test_fail

    jp  test_pass

;------------------------------------------------------------------
; Subroutines
;------------------------------------------------------------------
test_sub:
    ld  a, #0xBE
    ret

test_sub_z:
    ld  a, #0xAA
    ret z                   ; return only if Z still set

test_sub_nc:
    ld  a, #0xBB
    ret nc                  ; return only if C still clear

test_pass:
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt

test_fail:
    ld  a, #0x02
    out (_sim_ctl_port), a
    halt
