; load_mem.asm – LD-07..14
;
;   LD-07  LD A,(BC) / LD A,(DE) / LD A,(nn)
;   LD-08  LD (BC),A / LD (DE),A / LD (nn),A
;   LD-09  LD rr,nn  (16-bit immediate: BC DE HL SP)
;   LD-10  LD HL,(nn) / LD (nn),HL
;   LD-11  LD rr,(nn) / LD (nn),rr  (ED-prefix: BC DE IX IY SP)
;   LD-12  LD SP,HL / LD SP,IX / LD SP,IY
;   LD-13  LDI / LDD / LDIR / LDDR
;   LD-14  PUSH/POP (AF BC DE HL IX IY) – overlap with STK; included for completeness

    .module load_mem

_sim_ctl_port = 0x80
_timeout_port = 0x82
MEM_BASE = 0x8000

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

; Section ID stored in RAM at 0x8FF0; test_fail reads and outputs it to MSG_PORT
SECTION_ID = 0x8FF0

main:
    ld  sp, #0xFFFF

    ;========================================================
    ; LD-08: LD (BC),A / LD (DE),A
    ;========================================================
    ld  a, #0x01
    ld  (SECTION_ID), a
    call heartbeat
    ld  bc, #0x8010
    ld  a, #0xCC
    ld  (bc), a             ; write 0xCC to 0x8010
    ld  hl, #0x8010
    ld  a, (hl)
    cp  a, #0xCC
    jp  nz, test_fail

    ld  de, #0x8020
    ld  a, #0xDD
    ld  (de), a             ; write 0xDD to 0x8020
    ld  hl, #0x8020
    ld  a, (hl)
    cp  a, #0xDD
    jp  nz, test_fail

    ;========================================================
    ; LD-07: LD A,(BC) / LD A,(DE) / LD A,(nn)
    ;========================================================
    ld  a, #0x02
    ld  (SECTION_ID), a
    call heartbeat
    ; Read back what we just wrote
    ld  bc, #0x8010
    ld  a, (bc)
    cp  a, #0xCC
    jp  nz, test_fail

    ld  de, #0x8020
    ld  a, (de)
    cp  a, #0xDD
    jp  nz, test_fail

    ; LD (nn),A then LD A,(nn)
    ld  a, #0xEE
    ld  (0x8030), a
    ld  a, #0x00
    ld  a, (0x8030)
    cp  a, #0xEE
    jp  nz, test_fail

    ;========================================================
    ; LD-09: LD rr,nn (16-bit immediate)
    ;========================================================
    ld  a, #0x03
    ld  (SECTION_ID), a
    call heartbeat
    ld  bc, #0x1234
    ld  a, b
    cp  a, #0x12
    jp  nz, test_fail
    ld  a, c
    cp  a, #0x34
    jp  nz, test_fail

    ld  de, #0x5678
    ld  a, d
    cp  a, #0x56
    jp  nz, test_fail
    ld  a, e
    cp  a, #0x78
    jp  nz, test_fail

    ld  hl, #0x9ABC
    ld  a, h
    cp  a, #0x9A
    jp  nz, test_fail
    ld  a, l
    cp  a, #0xBC
    jp  nz, test_fail

    ;========================================================
    ; LD-10: LD (nn),HL / LD HL,(nn)
    ;========================================================
    ld  a, #0x04
    ld  (SECTION_ID), a
    call heartbeat
    ld  hl, #0xABCD
    ld  (0x8040), hl
    ld  hl, #0x0000
    ld  hl, (0x8040)
    ld  a, h
    cp  a, #0xAB
    jp  nz, test_fail
    ld  a, l
    cp  a, #0xCD
    jp  nz, test_fail

    ;========================================================
    ; LD-11: LD rr,(nn) / LD (nn),rr  (ED-prefix 16-bit indirect)
    ;========================================================
    ld  a, #0x05
    ld  (SECTION_ID), a
    call heartbeat
    ; LD (nn),BC: store BC=0x1234 at 0x8050
    ld  bc, #0x1234
    .db 0xED, 0x43, 0x50, 0x80  ; LD (0x8050),BC
    ld  hl, #0x8050
    ld  a, (hl)
    cp  a, #0x34            ; low byte first (little-endian)
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x12
    jp  nz, test_fail

    ; LD BC,(nn): reload BC from 0x8050
    ld  bc, #0x0000
    .db 0xED, 0x4B, 0x50, 0x80  ; LD BC,(0x8050)
    ld  a, b
    cp  a, #0x12
    jp  nz, test_fail
    ld  a, c
    cp  a, #0x34
    jp  nz, test_fail

    ; LD (nn),DE
    ld  de, #0x5678
    .db 0xED, 0x53, 0x60, 0x80  ; LD (0x8060),DE
    .db 0xED, 0x5B, 0x60, 0x80  ; LD DE,(0x8060)
    ld  a, d
    cp  a, #0x56
    jp  nz, test_fail
    ld  a, e
    cp  a, #0x78
    jp  nz, test_fail

    ; LD (nn),SP
    ld  sp, #0x9ABC
    .db 0xED, 0x73, 0x70, 0x80  ; LD (0x8070),SP
    .db 0xED, 0x7B, 0x70, 0x80  ; LD SP,(0x8070)
    ; Verify SP via another store
    .db 0xED, 0x73, 0x72, 0x80  ; LD (0x8072),SP
    ld  hl, #0x8072
    ld  a, (hl)
    cp  a, #0xBC            ; low byte
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x9A            ; high byte
    jp  nz, test_fail

    ; LD (nn),IX / LD IX,(nn) – verify via PUSH IX / POP HL (avoids undocumented IXH/IXL)
    .db 0xDD, 0x21, 0x11, 0x22  ; LD IX,0x2211
    .db 0xDD, 0x22, 0x80, 0x80  ; LD (0x8080),IX
    .db 0xDD, 0x2A, 0x80, 0x80  ; LD IX,(0x8080)
    ; Read IX back via PUSH IX / POP HL
    .db 0xDD, 0xE5              ; PUSH IX
    pop  hl
    ld   a, h
    cp   a, #0x22               ; IXH
    jp   nz, test_fail
    ld   a, l
    cp   a, #0x11               ; IXL
    jp   nz, test_fail

    ;========================================================
    ; LD-12: LD SP,HL / LD SP,IX / LD SP,IY
    ;========================================================
    ld  a, #0x06
    ld  (SECTION_ID), a
    call heartbeat
    ld  hl, #0x8FFE         ; set SP via HL (must be valid for stack use later)
    ld  sp, hl
    .db 0xED, 0x73, 0x90, 0x80  ; LD (0x8090),SP
    ld  hl, #0x8090
    ld  a, (hl)
    cp  a, #0xFE
    jp  nz, test_fail
    inc hl
    ld  a, (hl)
    cp  a, #0x8F
    jp  nz, test_fail

    ; Restore SP to safe value
    ld  sp, #0xFFFF

    ; LD SP,IX
    .db 0xDD, 0x21, 0x34, 0x8F  ; LD IX,0x8F34
    .db 0xDD, 0xF9              ; LD SP,IX
    .db 0xED, 0x73, 0x92, 0x80  ; LD (0x8092),SP
    ld  hl, #0x8092
    ld  a, (hl)
    cp  a, #0x34
    jp  nz, test_fail
    ld  sp, #0xFFFF         ; restore

    ;========================================================
    ; LD-13: LDI / LDD / LDIR / LDDR
    ;========================================================
    ld  a, #0x71
    ld  (SECTION_ID), a
    call heartbeat
    ; Prepare source buffer at 0x8100: bytes 0x01..0x08
    ld  hl, #0x8100
    ld  b, #8
    ld  c, #1
ldir_init:
    ld  (hl), c
    inc hl
    inc c
    djnz ldir_init

    ; LDIR: copy 8 bytes from 0x8100 to 0x8200
    ld  hl, #0x8100         ; source
    ld  de, #0x8200         ; dest
    ld  bc, #8              ; count
    call heartbeat          ; fresh budget for LDIR (block copy may use many cycles)
    .db 0xED, 0xB0          ; LDIR
    ; Check PV=0 immediately before any ALU clobbers flags
    jp  pe, ldir_pv_fail    ; 72: LDIR PV set when BC=0 (should be clear)
    ; Check BC=0
    ld  a, #0x71
    ld  (SECTION_ID), a
    ld  a, b
    or  a, c
    jp  nz, test_fail       ; 71: LDIR BC not zero
    jp  verify_ldir_start
ldir_pv_fail:
    ld  a, #0x72
    ld  (SECTION_ID), a
    jp  test_fail
verify_ldir_start:

    ; Verify copy
    ld  a, #0x73
    ld  (SECTION_ID), a
    ld  hl, #0x8200
    ld  b, #1
verify_ldir:
    ld  a, (hl)
    cp  a, b
    jp  nz, test_fail       ; 73: LDIR copy data wrong
    inc hl
    inc b
    ld  a, b
    cp  a, #9
    jp  nz, verify_ldir

    ; LDI: single transfer 0x8100[0] → 0x8300[0]
    ld  a, #0x74
    ld  (SECTION_ID), a
    ld  hl, #0x8100
    ld  de, #0x8300
    ld  bc, #4
    .db 0xED, 0xA0          ; LDI
    ld  a, b
    cp  a, #0x00
    jp  nz, test_fail_ldi_bc
    ld  a, #0x75
    ld  (SECTION_ID), a
    ld  a, c
    cp  a, #0x03
    jp  nz, test_fail       ; 75: LDI BC.C wrong
    ld  a, #0x76
    ld  (SECTION_ID), a
    ld  hl, #0x8300
    ld  a, (hl)
    cp  a, #0x01
    jp  nz, test_fail       ; 76: LDI data wrong
    jp  after_ldi
test_fail_ldi_bc:
    jp  test_fail           ; 74: LDI BC.B wrong
after_ldi:

    ; LDDR: copy 4 bytes backwards from 0x8103 to 0x8403
    ld  a, #0x77
    ld  (SECTION_ID), a
    ld  hl, #0x8103         ; last byte of source block
    ld  de, #0x8403         ; last byte of dest block
    ld  bc, #4
    call heartbeat          ; fresh budget for LDDR (block copy may use many cycles)
    .db 0xED, 0xB8          ; LDDR
    ; Check PV=0 immediately before any ALU clobbers flags
    jp  pe, lddr_pv_fail    ; 77b: LDDR PV set when BC=0 (should be clear)
    ; Check BC=0
    ld  a, b
    or  a, c
    jp  nz, test_fail       ; 77: LDDR BC not zero
    jp  after_lddr
lddr_pv_fail:
    ld  a, #0x7B
    ld  (SECTION_ID), a
    jp  test_fail
after_lddr:

    ; LDD: single reverse transfer
    ld  a, #0x78
    ld  (SECTION_ID), a
    ld  hl, #0x8103
    ld  de, #0x8503
    ld  bc, #2
    .db 0xED, 0xA8          ; LDD
    ld  a, c
    cp  a, #0x01
    jp  nz, test_fail       ; 78: LDD BC.C wrong
    ld  a, #0x79
    ld  (SECTION_ID), a
    ld  hl, #0x8503
    ld  a, (hl)
    cp  a, #0x04            ; byte at 0x8103 is 0x04
    jp  nz, test_fail       ; 79: LDD data wrong

    jp  test_pass

test_pass:
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt

test_fail:
    push af
    push bc
    ld  a, (SECTION_ID)
    ld  b, a
    ; output high nibble
    rlca
    rlca
    rlca
    rlca
    and a, #0x0F
    add a, #0x30
    out (0x81), a
    ; output low nibble
    ld  a, b
    and a, #0x0F
    add a, #0x30
    out (0x81), a
    ld  a, #0x0A
    out (0x81), a           ; newline to flush
    pop bc
    pop af
    ld  a, #0x02
    out (_sim_ctl_port), a
    halt
