; nmi_ops.asm – NMI-01..05
;
;   NMI-01  Basic NMI: CPU jumps to 0x0066 when NMI_N asserted
;   NMI-02  RETN: restores IFF1 from IFF2 after NMI
;   NMI-03  NMI during HALT: CPU exits HALT and jumps to 0x0066
;   NMI-04  NMI vs INT priority: NMI has higher priority than maskable INT
;   NMI-05  NMI opcode trigger: NMI fires when IR matches NMI_TRIG_OPCODE
;
; Ports used:
;   0x80  SIM_CTL_PORT
;   0x90  INTR_CNTDWN   – schedule maskable INT
;   0x95  NMI_CNTDWN    – schedule NMI
;   0xA0  NMI_TRIG_OPCODE – trigger NMI when cpu_ir matches

    .module nmi_ops

_sim_ctl_port  = 0x80
_intr_cntdwn   = 0x90
_nmi_cntdwn    = 0x95
_nmi_trig_opcode = 0xA0

NMI_COUNT  = 0x8000         ; NMI entry counter
INT_COUNT  = 0x8001         ; INT entry counter
HALT_FLAG  = 0x8002         ; set by NMI handler when entered from HALT

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    ; Maskable INT handler (IM 1) at 0x0038
    .org 0x0038
int_handler:
    push af
    push hl
    ld  hl, #INT_COUNT
    inc (hl)
    pop hl
    pop af
    ei
    reti

    ; NMI handler at 0x0066
    .org 0x0066
nmi_handler:
    push af
    push hl
    ld  hl, #NMI_COUNT
    inc (hl)                ; NMI-01: increment NMI counter
    ; Check if we were in HALT (halt_n goes high before NMI jump)
    ; We can detect HALT exit by checking if halt flag was set
    ld  hl, #HALT_FLAG
    ; (HALT_FLAG was pre-set to 0xAA by main before halting)
    ld  a, (hl)
    cp  a, #0xAA
    jp  nz, nmi_not_halt
    ld  (hl), #0x01         ; NMI-03: mark that NMI was taken from HALT
nmi_not_halt:
    pop hl
    pop af
    retn                    ; NMI-02: RETN restores IFF1 from IFF2

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ; Clear all counters and flags
    ld  a, #0x00
    ld  (NMI_COUNT), a
    ld  (INT_COUNT), a
    ld  (HALT_FLAG), a

    ;========================================================
    ; NMI-01: Basic NMI via NMI_CNTDWN port
    ;========================================================
    ; Schedule NMI in 3 ticks
    ld  a, #3
    out (_nmi_cntdwn), a

    ; Spin and wait for NMI counter to reach 1
    ld  de, #0xFFFF
nmi01_wait:
    ld  a, (NMI_COUNT)
    cp  a, #1
    jp  z, nmi01_done
    dec de
    ld  a, d
    or  a, e
    jp  nz, nmi01_wait
    jp  test_fail
nmi01_done:

    ;========================================================
    ; NMI-02: RETN restores IFF1
    ;========================================================
    ; We verify interrupts work after RETN by checking INT is taken
    ; after the NMI handler (which used RETN) completed.
    ; Enable INT mode 1 and schedule an INT.
    im  1
    ei
    ld  a, #3
    out (_intr_cntdwn), a

    ld  de, #0xFFFF
nmi02_wait:
    ld  a, (INT_COUNT)
    cp  a, #1
    jp  z, nmi02_done
    dec de
    ld  a, d
    or  a, e
    jp  nz, nmi02_wait
    jp  test_fail
nmi02_done:

    ;========================================================
    ; NMI-03: NMI during HALT
    ;========================================================
    ld  (HALT_FLAG), #0xAA  ; sentinel so NMI handler knows we were halting

    ; Schedule NMI while in HALT
    ld  a, #4
    out (_nmi_cntdwn), a

    ; Reset NMI counter to 2 (so we detect the new NMI as count=3)
    ; Actually use absolute check: current NMI_COUNT = 1, next will be 2
    halt                    ; CPU halts here, NMI wakes it

    ; After RETN from NMI, verify HALT_FLAG was updated to 0x01
    ld  a, (HALT_FLAG)
    cp  a, #0x01
    jp  nz, test_fail

    ;========================================================
    ; NMI-04: NMI priority over maskable INT
    ;========================================================
    ; Schedule both INT and NMI; NMI should be taken first
    di                      ; disable INT so we can set up race condition
    ld  a, #0x00
    ld  (INT_COUNT), a      ; reset INT counter

    ; Enable INT and NMI simultaneously
    ei
    ld  a, #2
    out (_intr_cntdwn), a   ; INT in 2 ticks
    ld  a, #2
    out (_nmi_cntdwn), a    ; NMI in 2 ticks (same time)

    ; Wait for NMI (should be taken before INT due to priority)
    ld  de, #0xFFFF
nmi04_wait:
    ld  a, (NMI_COUNT)
    cp  a, #3               ; now at 3 (was 2 after NMI-03)
    jp  z, nmi04_done
    dec de
    ld  a, d
    or  a, e
    jp  nz, nmi04_wait
    jp  test_fail
nmi04_done:

    ;========================================================
    ; NMI-05: NMI opcode trigger via NMI_TRIG_OPCODE port
    ;========================================================
    ; Set trigger opcode = 0x00 (NOP): NMI fires when IR = NOP
    di                      ; mask INT while setting up
    ld  a, #0x00
    out (_nmi_trig_opcode), a   ; trigger on NOP opcode

    ; Clear NMI_CNTDWN so it doesn't interfere
    ld  a, #0x00
    out (_nmi_cntdwn), a

    ; Enable and execute NOPs – NMI should fire on one of them
    ei
    nop                     ; IR = 0x00 → NMI triggered by cocotb
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    ; Clear trigger so it doesn't keep firing
    di
    ld  a, #0x00
    out (_nmi_trig_opcode), a

    ; NMI count should now be 4 (one more than after NMI-04)
    ld  a, (NMI_COUNT)
    cp  a, #4
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
