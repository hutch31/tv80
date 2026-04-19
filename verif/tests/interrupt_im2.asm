; interrupt_im2.asm – INT-03
;
; Test IM 2 (interrupt mode 2):
;   The CPU forms the ISR address as { I[7:0], data_bus[7:0] }.
;   The cocotb io_model drives int_ack_byte=0x00 on io_din during int_ack.
;   The test sets I=0x80 so the ISR address = 0x8000.
;   A vector table at 0x8000..0x8001 holds the actual ISR start address.
;
; Test sequence:
;   1. Build vector table at RAM 0x8000: [lo_byte, hi_byte] of isr_im2
;   2. LD I,A with A=0x80 (I register = 0x80)
;   3. IM 2, EI
;   4. Request INT via INTR_CNTDWN
;   5. CPU reads 0x00 from data bus during int_ack → ISR addr = 0x8000
;      → reads 16-bit vector from 0x8000 → jumps to isr_im2
;   6. ISR sets flag at 0x8010
;   7. Main verifies flag → PASS

    .module interrupt_im2

_sim_ctl_port = 0x80
_intr_cntdwn  = 0x90

    .area PROGMEM (ABS)
    .org 0x0000
    jp  main

    ; Note: 0x0038 handler not needed for IM2, but put a safety RETI there
    .org 0x0038
    reti

    ; ISR for IM 2 – placed in ROM so PC can reach it
    ; We put it at a known ROM address that we'll embed in the vector table
isr_im2:
    push af
    push hl
    ld  hl, #0x8010
    ld  (hl), #0x01         ; set "ISR ran" flag
    pop hl
    pop af
    ei
    reti

    .org 0x0100
main:
    ld  sp, #0xFFFF

    ; Clear flags
    ld  hl, #0x8010
    ld  (hl), #0x00

    ; Build vector table at 0x8000:
    ;   [0x8000] = low byte of isr_im2 address
    ;   [0x8001] = high byte of isr_im2 address
    ld  hl, #0x8000
    ld  (hl), #<isr_im2
    inc hl
    ld  (hl), #>isr_im2

    ; Set I = 0x80
    ld  a, #0x80
    .db 0xED, 0x47          ; LD I,A

    ; Select IM 2 and enable interrupts
    .db 0xED, 0x5E          ; IM 2
    ei

    ; Request INT in 3 ticks
    ld  a, #3
    out (_intr_cntdwn), a

    ; Poll ISR flag with timeout
    ld  de, #0xFFFF
wait_loop:
    ld  a, (0x8010)
    cp  a, #1
    jp  z, check_done
    dec de
    ld  a, d
    or  a, e
    jp  nz, wait_loop
    jp  test_fail

check_done:
    jp  test_pass

test_pass:
    ld  a, #0x01
    out (_sim_ctl_port), a
    halt

test_fail:
    ld  a, #0x02
    out (_sim_ctl_port), a
    halt
