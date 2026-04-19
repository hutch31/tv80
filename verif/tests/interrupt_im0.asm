; interrupt_im0.asm – INT-01
;
; Test IM 0 (interrupt mode 0):
;   The CPU samples the data bus during the INT-acknowledge cycle and
;   executes that byte as an instruction.  The cocotb io_model drives
;   0xFF on io_din during int_ack (= RST 38H).
;
; Test sequence:
;   1. Set IM 0, EI
;   2. Request INT via INTR_CNTDWN port
;   3. CPU samples 0xFF from io_din → executes RST 38H → jumps to 0x0038
;   4. ISR at 0x0038 increments counter at 0x8000 and executes RETI
;   5. Main code verifies counter == 1 → PASS

    .module interrupt_im0

_sim_ctl_port = 0x80
_intr_cntdwn  = 0x90

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    ; RST 38H / INT mode 1 handler at 0x0038
    .org 0x0038
isr_im0:
    push af
    push hl
    ld  hl, #0x8000
    inc (hl)                ; increment ISR entry counter
    pop hl
    pop af
    ei
    reti

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ; Clear ISR counter
    ld  hl, #0x8000
    ld  (hl), #0x00

    ; Configure IM 0 and enable interrupts
    .db 0xED, 0x46          ; IM 0
    ei

    ; Request an interrupt in 3 io_model ticks (countdown → 1 → fires)
    ld  a, #3
    out (_intr_cntdwn), a

    ; Wait for ISR (poll counter, timeout loop)
    ld  de, #0xFFFF         ; timeout counter
wait_loop:
    ld  a, (0x8000)
    cp  a, #1
    jp  z, check_done       ; ISR ran
    dec de
    ld  a, d
    or  a, e
    jp  nz, wait_loop
    jp  test_fail           ; timeout

check_done:
    ; Verify counter is exactly 1
    ld  a, (0x8000)
    cp  a, #1
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
