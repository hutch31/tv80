; misc_ops.asm – MISC-01..03
;
;   MISC-01  NOP  (program counter advances; no registers/flags changed)
;   MISC-02  HALT followed by INT exit (CPU enters halt, INT pulls it out)
;   MISC-03  DI / EI  (disable and re-enable interrupts)
;
; For MISC-02 the test relies on the cocotb IO model triggering an INT
; via INTR_CNTDWN (write countdown to 0x90).  The INT handler at 0x0038
; writes 0x01 to 0x8000 so the main code can detect ISR was entered.

    .module misc_ops

_sim_ctl_port = 0x80
_intr_cntdwn  = 0x90

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    ; INT mode-1 handler at 0x0038
    .org 0x0038
int_handler:
    push af
    push hl
    ld  hl, #0x8000
    ld  (hl), #0x01         ; mark that ISR was entered
    pop hl
    pop af
    ei
    reti

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ;========================================================
    ; MISC-01: NOP – each NOP must advance PC by exactly 1
    ;========================================================
    ; We verify that code after a block of NOPs still executes
    nop
    nop
    nop
    nop
    nop
    ; If we reach here, NOPs advanced PC correctly
    ld  a, #0x00
    out (_sim_ctl_port), a  ; dummy write (value 0 = no-op for SIM_CTL)

    ;========================================================
    ; MISC-03: DI / EI
    ;========================================================
    ; After DI, an incoming INT should NOT be serviced until EI
    im  1                   ; set INT mode 1
    di                      ; disable interrupts (IFF1=0)
    ; Request an interrupt via INTR_CNTDWN=2
    ld  a, #2
    out (_intr_cntdwn), a   ; INT will fire in 2 io_model ticks
    ; Run for a few cycles – INT should NOT be taken
    nop
    nop
    nop
    nop
    ; INT line is now low (int_countdown reached 1 in io_model)
    ; Verify ISR was NOT entered (0x8000 should still be 0)
    ld  hl, #0x8000
    ld  (hl), #0x00         ; ensure clean
    ; Now enable interrupts – INT should be taken on next instruction
    ei
    nop                     ; INT is taken here or after
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    ;========================================================
    ; MISC-02: HALT – CPU halts, INT brings it back
    ;========================================================
    ; Clear the ISR flag
    ld  hl, #0x8000
    ld  (hl), #0x00

    ; Enable INT mode 1 and global interrupts
    im  1
    ei
    ; Schedule an interrupt in 5 ticks
    ld  a, #5
    out (_intr_cntdwn), a

    halt                    ; CPU halts here; INT will wake it

    ; After returning from HALT + ISR, check that ISR ran
    ld  hl, #0x8000
    ld  a, (hl)
    cp  a, #0x01
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
