;--------------------------------------------------------
; File Created by SDCC : free open source ANSI-C Compiler
; Version 2.9.0 #5416 (Dec  7 2009) (UNIX)
; This file was generated Thu Aug 12 22:26:01 2010
;--------------------------------------------------------
	.module bintr
	.optsdcc -mz80
	
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _main
	.globl _isr
	.globl _nmi_isr
	.globl _set_timeout
	.globl _print_num
	.globl _print_hex
	.globl _print
	.globl _nmi_trig
	.globl _done
	.globl _loop
	.globl _phase
	.globl _test_pass
	.globl _foo
;--------------------------------------------------------
; special function registers
;--------------------------------------------------------
_sim_ctl_port	=	0x0080
_msg_port	=	0x0081
_timeout_port	=	0x0082
_max_timeout_low	=	0x0083
_max_timeout_high	=	0x0084
_intr_cntdwn	=	0x0090
_cksum_value	=	0x0091
_cksum_accum	=	0x0092
_inc_on_read	=	0x0093
_randval	=	0x0094
_nmi_cntdwn	=	0x0095
_nmi_trig_opcode	=	0x00a0
;--------------------------------------------------------
;  ram data
;--------------------------------------------------------
	.area _DATA
_foo::
	.ds 1
_test_pass::
	.ds 1
_triggers:
	.ds 1
_phase::
	.ds 2
_loop::
	.ds 2
_done::
	.ds 1
_nmi_trig::
	.ds 1
;--------------------------------------------------------
; overlayable items in  ram 
;--------------------------------------------------------
	.area _OVERLAY
;--------------------------------------------------------
; external initialized ram data
;--------------------------------------------------------
;--------------------------------------------------------
; global & static initialisations
;--------------------------------------------------------
	.area _HOME
	.area _GSINIT
	.area _GSFINAL
	.area _GSINIT
;--------------------------------------------------------
; Home
;--------------------------------------------------------
	.area _HOME
	.area _HOME
;--------------------------------------------------------
; code
;--------------------------------------------------------
	.area _CODE
;tv80_env.h:49: void print (char *string)
;	---------------------------------
; Function print
; ---------------------------------
_print_start::
_print:
	push	ix
	ld	ix,#0
	add	ix,sp
;tv80_env.h:54: timeout = timeout_port;
	in	a,(_timeout_port)
	ld	c,a
;tv80_env.h:55: timeout_port = 0x02;
	ld	a,#0x02
	out	(_timeout_port),a
;tv80_env.h:56: timeout_port = timeout;
	ld	a,c
	out	(_timeout_port),a
;tv80_env.h:58: iter = string;
	ld	c,4 (ix)
	ld	b,5 (ix)
;tv80_env.h:59: while (*iter != 0) {
00101$:
	ld	a,(bc)
	ld	e,a
	or	a,a
	jr	Z,00104$
;tv80_env.h:60: msg_port = *iter++;
	ld	a,e
	out	(_msg_port),a
	inc	bc
	jr	00101$
00104$:
	pop	ix
	ret
_print_end::
;tv80_env.h:64: void print_hex (unsigned int num)
;	---------------------------------
; Function print_hex
; ---------------------------------
_print_hex_start::
_print_hex:
	push	ix
	ld	ix,#0
	add	ix,sp
;tv80_env.h:68: for (i=3; i>=0; i--) {
	ld	c,#0x03
00104$:
	ld	a,c
	bit	7,a
	jr	NZ,00108$
;tv80_env.h:69: digit = (num >> (i*4)) & 0xf;
	ld	a,c
	ld	e,a
	rla	
	sbc	a,a
	ld	d,a
	sla	e
	rl	d
	sla	e
	rl	d
	ld	a,e
	inc	a
	push	af
	ld	e,4 (ix)
	ld	d,5 (ix)
	pop	af
	jr	00117$
00116$:
	srl	d
	rr	e
00117$:
	dec	a
	jr	NZ,00116$
	ld	a,e
	and	a,#0x0F
	ld	e,a
	ld	d,#0x00
;tv80_env.h:70: if (digit < 10) msg_port = digit + '0';
	ld	b,a
	sub	a,#0x0A
	jp	P,00102$
	ld	a,b
	add	a,#0x30
	out	(_msg_port),a
	jr	00106$
00102$:
;tv80_env.h:71: else msg_port = digit + 'a' - 10;
	ld	a,b
	add	a,#0x57
	out	(_msg_port),a
00106$:
;tv80_env.h:68: for (i=3; i>=0; i--) {
	dec	c
	jr	00104$
00108$:
	pop	ix
	ret
_print_hex_end::
;tv80_env.h:75: void print_num (int num)
;	---------------------------------
; Function print_num
; ---------------------------------
_print_num_start::
_print_num:
	push	ix
	ld	ix,#0
	add	ix,sp
	ld	hl,#-12
	add	hl,sp
	ld	sp,hl
;tv80_env.h:82: timeout = timeout_port;
	in	a,(_timeout_port)
	ld	c,a
;tv80_env.h:83: timeout_port = 0x02;
	ld	a,#0x02
	out	(_timeout_port),a
;tv80_env.h:84: timeout_port = timeout;
	ld	a,c
	out	(_timeout_port),a
;tv80_env.h:86: if (num == 0) { msg_port = '0'; return; }
	ld	a,4 (ix)
	or	a,5 (ix)
	jr	NZ,00114$
	ld	a,#0x30
	out	(_msg_port),a
	jp	00110$
;tv80_env.h:87: while (num > 0) {
00114$:
	ld	hl,#0x0004
	add	hl,sp
	ld	-12 (ix),l
	ld	-11 (ix),h
	ld	c,#0x00
00103$:
	ld	a,#0x00
	sub	a,4 (ix)
	ld	a,#0x00
	sbc	a,5 (ix)
	jp	P,00105$
;tv80_env.h:88: digits[cd++] = (num % 10) + '0';
	ld	d,c
	inc	c
	ld	a,-12 (ix)
	add	a,d
	ld	-10 (ix),a
	ld	a,-11 (ix)
	adc	a,#0x00
	ld	-9 (ix),a
	push	bc
	ld	hl,#0x000A
	push	hl
	ld	l,4 (ix)
	ld	h,5 (ix)
	push	hl
	call	__modsint_rrx_s
	pop	af
	pop	af
	ld	e,l
	pop	bc
	ld	a,e
	add	a,#0x30
	ld	l,-10 (ix)
	ld	h,-9 (ix)
	ld	(hl),a
;tv80_env.h:89: num /= 10;
	push	bc
	ld	hl,#0x000A
	push	hl
	ld	l,4 (ix)
	ld	h,5 (ix)
	push	hl
	call	__divsint_rrx_s
	pop	af
	pop	af
	ld	d,h
	ld	e,l
	pop	bc
	ld	4 (ix),e
	ld	5 (ix),d
	jp	00103$
00105$:
;tv80_env.h:91: for (i=cd; i>0; i--)
	ld	a,c
	ld	e,a
	rla	
	sbc	a,a
	ld	d,a
00106$:
	ld	a,#0x00
	sub	a,e
	ld	a,#0x00
	sbc	a,d
	jp	P,00110$
;tv80_env.h:92: msg_port = digits[i-1];
	ld	c,e
	dec	c
	ld	a,-12 (ix)
	add	a,c
	ld	c,a
	ld	a,-11 (ix)
	adc	a,#0x00
	ld	b,a
	ld	a,(bc)
	out	(_msg_port),a
;tv80_env.h:91: for (i=cd; i>0; i--)
	dec	de
	jr	00106$
00110$:
	ld	sp,ix
	pop	ix
	ret
_print_num_end::
;tv80_env.h:97: void set_timeout (unsigned int max_timeout)
;	---------------------------------
; Function set_timeout
; ---------------------------------
_set_timeout_start::
_set_timeout:
	push	ix
	ld	ix,#0
	add	ix,sp
;tv80_env.h:99: timeout_port = 0x02;
	ld	a,#0x02
	out	(_timeout_port),a
;tv80_env.h:101: max_timeout_low = (max_timeout & 0xFF);
	ld	c,4 (ix)
	ld	b,#0x00
	ld	a,c
	out	(_max_timeout_low),a
;tv80_env.h:102: max_timeout_high = (max_timeout >> 8);
	ld	c,5 (ix)
	ld	b,#0x00
	ld	a,c
	out	(_max_timeout_high),a
;tv80_env.h:104: timeout_port = 0x01;
	ld	a,#0x01
	out	(_timeout_port),a
	pop	ix
	ret
_set_timeout_end::
;bintr.c:23: void nmi_isr (void)
;	---------------------------------
; Function nmi_isr
; ---------------------------------
_nmi_isr_start::
_nmi_isr:
;bintr.c:25: nmi_trig++;
	ld	iy,#_nmi_trig
	inc	0 (iy)
;bintr.c:27: switch (phase) {
	ld	a,(#_phase+0)
	sub	a,#0x01
	ret	NZ
	ld	a,(#_phase+1)
	or	a,a
	jr	Z,00111$
	ret
00111$:
;bintr.c:30: if (nmi_trig > 5) {
	ld	a,#0x05
	ld	iy,#_nmi_trig
	sub	a,0 (iy)
	jp	P,00103$
;bintr.c:31: phase += 1;
	ld	iy,#_phase
	inc	0 (iy)
	jr	NZ,00112$
	ld	iy,#_phase
	inc	1 (iy)
00112$:
;bintr.c:32: nmi_trig = 0;
	ld	hl,#_nmi_trig + 0
	ld	(hl), #0x00
;bintr.c:35: print ("Final interrupt\n");
	ld	hl,#__str_0
	push	hl
	call	_print
	pop	af
;bintr.c:36: intr_cntdwn = 32;
	ld	a,#0x20
	out	(_intr_cntdwn),a
;bintr.c:37: nmi_cntdwn = 0;
	ld	a,#0x00
	out	(_nmi_cntdwn),a
	ret
00103$:
;bintr.c:39: nmi_cntdwn = 32;
	ld	a,#0x20
	out	(_nmi_cntdwn),a
;bintr.c:41: }
	ret
_nmi_isr_end::
__str_0:
	.ascii "Final interrupt"
	.db 0x0A
	.db 0x00
;bintr.c:44: void isr (void)
;	---------------------------------
; Function isr
; ---------------------------------
_isr_start::
_isr:
;bintr.c:46: triggers++;
	ld	iy,#_triggers
	inc	0 (iy)
;bintr.c:48: switch (phase) {
	ld	a,(#_phase+0)
	ld	iy,#_phase
	or	a,1 (iy)
	jr	Z,00101$
	ld	a,(#_phase+0)
	sub	a,#0x02
	ret	NZ
	ld	iy,#_phase
	ld	a,1 (iy)
	or	a,a
	jr	Z,00105$
	ret
;bintr.c:50: case 0 :
00101$:
;bintr.c:51: if (triggers > 5) {
	ld	a,#0x05
	ld	iy,#_triggers
	sub	a,0 (iy)
	jr	NC,00103$
;bintr.c:52: phase += 1;
	ld	iy,#_phase
	inc	0 (iy)
	jr	NZ,00114$
	ld	iy,#_phase
	inc	1 (iy)
00114$:
;bintr.c:53: triggers = 0;
	ld	iy,#_triggers
	ld	0 (iy),#0x00
;bintr.c:54: intr_cntdwn = 0;
	ld	a,#0x00
	out	(_intr_cntdwn),a
;bintr.c:55: print ("Starting NMIs\n");
	ld	hl,#__str_1
	push	hl
	call	_print
	pop	af
;bintr.c:56: nmi_cntdwn = 64;
	ld	a,#0x40
	out	(_nmi_cntdwn),a
	ret
00103$:
;bintr.c:58: intr_cntdwn = 32;
	ld	a,#0x20
	out	(_intr_cntdwn),a
;bintr.c:61: break;
	ret
;bintr.c:64: case 2 :
00105$:
;bintr.c:65: intr_cntdwn = 0;
	ld	a,#0x00
	out	(_intr_cntdwn),a
;bintr.c:66: test_pass = 1;
	ld	hl,#_test_pass + 0
	ld	(hl), #0x01
;bintr.c:68: }
	ret
_isr_end::
__str_1:
	.ascii "Starting NMIs"
	.db 0x0A
	.db 0x00
;bintr.c:71: int main ()
;	---------------------------------
; Function main
; ---------------------------------
_main_start::
_main:
;bintr.c:76: test_pass = 0;
	ld	hl,#_test_pass + 0
	ld	(hl), #0x00
;bintr.c:77: triggers = 0;
	ld	hl,#_triggers + 0
	ld	(hl), #0x00
;bintr.c:78: nmi_trig = 0;
	ld	hl,#_nmi_trig + 0
	ld	(hl), #0x00
;bintr.c:80: phase = 0;
	ld	hl,#_phase + 0
	ld	(hl), #0x00
	ld	hl,#_phase + 1
	ld	(hl), #0x00
;bintr.c:83: print ("Starting interrupts\n");
	ld	hl,#__str_2
	push	hl
	call	_print
	pop	af
;bintr.c:84: intr_cntdwn = 64;
	ld	a,#0x40
	out	(_intr_cntdwn),a
;bintr.c:85: set_timeout (50000);
	ld	hl,#0xC350
	push	hl
	call	_set_timeout
;bintr.c:87: for (loop=0; loop<1024; loop++) {
	ld	a,#0x00
	ld	(#_loop + 0),a
	pop	af
	ld	iy,#_loop
	ld	1 (iy),#0x00
00103$:
	ld	a,(#_loop+0)
	sub	a,#0x00
	ld	a,(#_loop+1)
	sbc	a,#0x04
	jp	P,00106$
;bintr.c:88: if (test_pass)
	xor	a,a
	ld	iy,#_test_pass
	or	a,0 (iy)
	jr	NZ,00106$
;bintr.c:90: check = sim_ctl_port;
	in	a,(_sim_ctl_port)
;bintr.c:87: for (loop=0; loop<1024; loop++) {
	ld	iy,#_loop
	inc	0 (iy)
	jr	NZ,00116$
	ld	iy,#_loop
	inc	1 (iy)
00116$:
	jr	00103$
00106$:
;bintr.c:93: if (test_pass)
	xor	a,a
	ld	iy,#_test_pass
	or	a,0 (iy)
	jr	Z,00108$
;bintr.c:94: sim_ctl (SC_TEST_PASSED);
	ld	a,#0x01
	out	(_sim_ctl_port),a
	jr	00109$
00108$:
;bintr.c:96: sim_ctl (SC_TEST_FAILED);
	ld	a,#0x02
	out	(_sim_ctl_port),a
00109$:
;bintr.c:98: return 0;
	ld	hl,#0x0000
	ret
_main_end::
__str_2:
	.ascii "Starting interrupts"
	.db 0x0A
	.db 0x00
	.area _CODE
	.area _CABS
