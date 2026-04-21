; io_ops.asm – IO-01..03
;
;   IO-01  IN A,(n) / OUT (n),A  (direct 8-bit port address)
;   IO-02  IN r,(C) / OUT (C),r  (BC register pair addressing, ED prefix)
;   IO-03  INI/IND/INIR/INDR / OUTI/OUTD/OTIR/OTDR  (block I/O)
;
; This program uses the following IO ports provided by the cocotb IO model:
;   0x80  SIM_CTL_PORT  – write 0x01=PASS 0x02=FAIL
;   0x91  CKSUM_VALUE   – readable/writable checksum register
;   0x92  CKSUM_ACCUM   – write byte to accumulate into checksum
;   0x93  INC_ON_READ   – readable/writable value
;   0x80..0x9F and 0xA0 – IO addresses the model responds to

    .module io_ops

_sim_ctl_port = 0x80
_timeout_port = 0x82
_cksum_value  = 0x91
_cksum_accum  = 0x92
_inc_on_read  = 0x93

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
    ; IO-01: OUT (n),A / IN A,(n)
    ;========================================================
    call heartbeat
    ; Write a known value to CKSUM_VALUE then read it back
    ld  a, #0x55
    out (_cksum_value), a   ; set checksum to 0x55
    ld  a, #0x00
    in  a, (_cksum_value)   ; read back
    cp  a, #0x55
    jp  nz, test_fail

    ; Set INC_ON_READ to 0xAA and read it back
    ld  a, #0xAA
    out (_inc_on_read), a
    in  a, (_inc_on_read)
    cp  a, #0xAA
    jp  nz, test_fail

    ; Accumulate bytes: write 0x01,0x02,0x03 to CKSUM_ACCUM
    ; reset checksum first
    ld  a, #0x00
    out (_cksum_value), a
    ld  a, #0x01
    out (_cksum_accum), a
    ld  a, #0x02
    out (_cksum_accum), a
    ld  a, #0x03
    out (_cksum_accum), a
    in  a, (_cksum_value)
    cp  a, #0x06            ; 0+1+2+3 = 6
    jp  nz, test_fail

    ;========================================================
    ; IO-02: IN r,(C) / OUT (C),r  (ED prefix)
    ;========================================================
    call heartbeat
    ; Set CKSUM_VALUE = 0x77 via OUT (n),A
    ld  a, #0x77
    out (_cksum_value), a

    ; IN A,(C) where C=0x91: read CKSUM_VALUE
    ld  bc, #0x0091         ; B=0x00 (unused by IO-02), C=0x91 (port)
    .db 0xED, 0x78          ; IN A,(C)
    cp  a, #0x77
    jp  nz, test_fail

    ; IN B,(C) where C=0x91
    .db 0xED, 0x40          ; IN B,(C)
    ld  a, b
    cp  a, #0x77
    jp  nz, test_fail

    ; IN C,(C) – reads from port C=0x91, puts result in C
    .db 0xED, 0x48          ; IN C,(C)
    ; C is now 0x77 but that changes the port address... avoid using C after this
    ; Just verify the value is non-zero and reasonable
    ld  a, c
    cp  a, #0x77
    jp  nz, test_fail

    ; Restore BC
    ld  bc, #0x0091

    ; OUT (C),A: write A=0x42 to port C=0x91 (CKSUM_VALUE)
    ld  a, #0x42
    .db 0xED, 0x79          ; OUT (C),A
    in  a, (_cksum_value)
    cp  a, #0x42
    jp  nz, test_fail

    ; OUT (C),B: write B=0x11 to port C=0x91
    ld  b, #0x11
    .db 0xED, 0x41          ; OUT (C),B
    in  a, (_cksum_value)
    cp  a, #0x11
    jp  nz, test_fail

    ;========================================================
    ; IO-03: Block I/O – OTIR / OTDR / OUTI / OUTD
    ;========================================================
    call heartbeat
    ; Initialize source buffer at 0x8100 with 0x01..0x08
    ld  hl, #0x8100
    ld  b, #8
    ld  c, #1
init_buf:
    ld  (hl), c
    inc hl
    inc c
    djnz init_buf

    ; Reset checksum to 0
    ld  a, #0
    out (_cksum_value), a

    ; -- heartbeat before block output --
    call heartbeat

    ; OTIR: output 8 bytes from 0x8100 to port C=0x92 (CKSUM_ACCUM)
    ld  hl, #0x8100
    ld  bc, #0x0892         ; B=8 (count), C=0x92 (CKSUM_ACCUM)
    .db 0xED, 0xB3          ; OTIR

    ; Verify checksum: 1+2+3+4+5+6+7+8 = 36 = 0x24
    in  a, (_cksum_value)
    cp  a, #0x24
    jp  nz, test_fail

    ; OUTI: single output (1 byte)
    ld  a, #0
    out (_cksum_value), a   ; reset checksum
    ld  hl, #0x8100
    ld  bc, #0x0292         ; B=2, C=0x92
    .db 0xED, 0xA3          ; OUTI  (transfers 1 byte from (HL) to port C, decrements B)
    in  a, (_cksum_value)
    cp  a, #0x01            ; only 1 byte sent
    jp  nz, test_fail
    ld  a, b
    cp  a, #0x01            ; B decremented from 2 to 1
    jp  nz, test_fail

    ; OUTD: single output backwards
    ld  a, #0
    out (_cksum_value), a
    ld  hl, #0x8104         ; point to 0x05 in the buffer (5th byte = 0x05)
    ld  bc, #0x0192         ; B=1, C=0x92
    .db 0xED, 0xAB          ; OUTD  (transfers (HL) to port, decrements HL, B)
    in  a, (_cksum_value)
    cp  a, #0x05
    jp  nz, test_fail

    ; OTDR: output backwards from 0x8107 (8th byte = 0x08) for 4 bytes
    ; This sends bytes at 0x8107,0x8106,0x8105,0x8104 = 8,7,6,5 → sum=26
    ld  a, #0
    out (_cksum_value), a
    ld  hl, #0x8107         ; last byte of the 8-byte buffer
    ld  bc, #0x0492         ; B=4, C=0x92
    .db 0xED, 0xBB          ; OTDR
    in  a, (_cksum_value)
    cp  a, #0x1A            ; 8+7+6+5=26=0x1A
    jp  nz, test_fail

    ; -- heartbeat before block input --
    call heartbeat

    ; INIR: input 4 bytes from CKSUM_VALUE into 0x8200..0x8203
    ; Each read of CKSUM_VALUE (0x91) returns 0x77 (set earlier)
    ld  a, #0x77
    out (_cksum_value), a
    ld  hl, #0x8200
    ld  bc, #0x0491         ; B=4, C=0x91 (CKSUM_VALUE = 0x77)
    .db 0xED, 0xB2          ; INIR
    ld  a, b
    jp  nz, test_fail       ; B must be 0
    ld  hl, #0x8200
    ld  a, (hl)
    cp  a, #0x77
    jp  nz, test_fail

    ; INI: single input
    ld  hl, #0x8300
    ld  bc, #0x0191         ; B=1, C=0x91
    .db 0xED, 0xA2          ; INI
    ld  a, (0x8300)
    cp  a, #0x77
    jp  nz, test_fail

    ; IND: single input backwards
    ld  hl, #0x8400
    ld  bc, #0x0191
    .db 0xED, 0xAA          ; IND
    ld  a, (0x8400)
    cp  a, #0x77
    jp  nz, test_fail

    ; INDR: 3 bytes backwards from 0x8502
    ld  hl, #0x8502
    ld  bc, #0x0391
    .db 0xED, 0xBA          ; INDR
    ld  a, b
    jp  nz, test_fail       ; B must be 0
    ld  a, (0x8500)
    cp  a, #0x77
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
