;--------------------------------------------------------
; File Created by SDCC : free open source ANSI-C Compiler
; Version 4.0.0 #11528 (Linux)
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
; ram data
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
; ram data
;--------------------------------------------------------
	.area _INITIALIZED
;--------------------------------------------------------
; absolute external ram data
;--------------------------------------------------------
	.area _DABS (ABS)
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
;tv80_env.h:53: void print (char *string)
;	---------------------------------
; Function print
; ---------------------------------
_print::
;tv80_env.h:58: timeout = timeout_port;
	in	a, (_timeout_port)
	ld	c, a
;tv80_env.h:59: timeout_port = 0x02;
	ld	a, #0x02
	out	(_timeout_port), a
;tv80_env.h:60: timeout_port = timeout;
	ld	a, c
	out	(_timeout_port), a
;tv80_env.h:62: iter = string;
	pop	de
	pop	bc
	push	bc
	push	de
;tv80_env.h:63: while (*iter != 0) {
00101$:
	ld	a, (bc)
	or	a, a
	ret	Z
;tv80_env.h:64: msg_port = *iter++;
	out	(_msg_port), a
	inc	bc
;tv80_env.h:66: }
	jr	00101$
;tv80_env.h:68: void print_hex (unsigned int num)
;	---------------------------------
; Function print_hex
; ---------------------------------
_print_hex::
;tv80_env.h:72: for (i=3; i>=0; i--) {
	ld	c, #0x03
00105$:
;tv80_env.h:73: digit = (num >> (i*4)) & 0xf;
	ld	a, c
	add	a, a
	add	a, a
	ld	b, a
	ld	hl, #2
	add	hl, sp
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	inc	b
	jr	00120$
00119$:
	srl	d
	rr	e
00120$:
	djnz	00119$
	ld	a, e
	and	a, #0x0f
;tv80_env.h:74: if (digit < 10) msg_port = digit + '0';
	ld	b, a
	sub	a, #0x0a
	jr	NC,00102$
	ld	a, b
	add	a, #0x30
	out	(_msg_port), a
	jr	00106$
00102$:
;tv80_env.h:75: else msg_port = digit + 'a' - 10;
	ld	a, b
	add	a, #0x57
	out	(_msg_port), a
00106$:
;tv80_env.h:72: for (i=3; i>=0; i--) {
	dec	c
;tv80_env.h:77: }
	jr	00105$
;tv80_env.h:79: void print_num (int num)
;	---------------------------------
; Function print_num
; ---------------------------------
_print_num::
	push	ix
	ld	ix,#0
	add	ix,sp
	ld	hl, #-10
	add	hl, sp
	ld	sp, hl
;tv80_env.h:86: timeout = timeout_port;
	in	a, (_timeout_port)
	ld	c, a
;tv80_env.h:87: timeout_port = 0x02;
	ld	a, #0x02
	out	(_timeout_port), a
;tv80_env.h:88: timeout_port = timeout;
	ld	a, c
	out	(_timeout_port), a
;tv80_env.h:90: if (num == 0) { msg_port = '0'; return; }
	ld	a, 5 (ix)
	or	a, 4 (ix)
	jr	NZ,00114$
	ld	a, #0x30
	out	(_msg_port), a
	jr	00110$
;tv80_env.h:91: while (num > 0) {
00114$:
	ld	hl, #0
	add	hl, sp
	ld	-2 (ix), l
	ld	-1 (ix), h
	ld	c, #0x00
00103$:
	xor	a, a
	cp	a, 4 (ix)
	sbc	a, 5 (ix)
	jp	PO, 00139$
	xor	a, #0x80
00139$:
	jp	P, 00105$
;tv80_env.h:92: digits[cd++] = (num % 10) + '0';
	ld	a, -2 (ix)
	add	a, c
	ld	e, a
	ld	a, -1 (ix)
	adc	a, #0x00
	ld	d, a
	inc	c
	push	bc
	push	de
	ld	hl, #0x000a
	push	hl
	ld	l, 4 (ix)
	ld	h, 5 (ix)
	push	hl
	call	__modsint
	pop	af
	pop	af
	pop	de
	pop	bc
	ld	a, l
	add	a, #0x30
	ld	(de), a
;tv80_env.h:93: num /= 10;
	push	bc
	ld	hl, #0x000a
	push	hl
	ld	l, 4 (ix)
	ld	h, 5 (ix)
	push	hl
	call	__divsint
	pop	af
	pop	af
	pop	bc
	ld	4 (ix), l
	ld	5 (ix), h
	jr	00103$
00105$:
;tv80_env.h:95: for (i=cd; i>0; i--)
	ld	b, #0x00
00108$:
	xor	a, a
	cp	a, c
	sbc	a, b
	jp	PO, 00140$
	xor	a, #0x80
00140$:
	jp	P, 00110$
;tv80_env.h:96: msg_port = digits[i-1];
	ld	a, c
	dec	a
	ld	e, a
	rla
	sbc	a, a
	ld	d, a
	ld	l, -2 (ix)
	ld	h, -1 (ix)
	add	hl, de
	ld	a, (hl)
	out	(_msg_port), a
;tv80_env.h:95: for (i=cd; i>0; i--)
	dec	bc
	jr	00108$
00110$:
;tv80_env.h:97: }
	ld	sp, ix
	pop	ix
	ret
;tv80_env.h:101: void set_timeout (unsigned int max_timeout)
;	---------------------------------
; Function set_timeout
; ---------------------------------
_set_timeout::
;tv80_env.h:103: timeout_port = 0x02;
	ld	a, #0x02
	out	(_timeout_port), a
;tv80_env.h:105: max_timeout_low = (max_timeout & 0xFF);
	ld	iy, #2
	add	iy, sp
	ld	a, 0 (iy)
	out	(_max_timeout_low), a
;tv80_env.h:106: max_timeout_high = (max_timeout >> 8);
	ld	a, 1 (iy)
	out	(_max_timeout_high), a
;tv80_env.h:108: timeout_port = 0x01;
	ld	a, #0x01
	out	(_timeout_port), a
;tv80_env.h:109: }
	ret
;bintr.c:23: void nmi_isr (void)
;	---------------------------------
; Function nmi_isr
; ---------------------------------
_nmi_isr::
;bintr.c:25: nmi_trig++;
	ld	hl, #_nmi_trig+0
	inc	(hl)
;bintr.c:27: switch (phase) {
	ld	iy, #_phase
	ld	a, 0 (iy)
	dec	a
	or	a, 1 (iy)
	ret	NZ
;bintr.c:30: if (nmi_trig > 5) {
	ld	a, #0x05
	ld	iy, #_nmi_trig
	sub	a, 0 (iy)
	jr	NC,00103$
;bintr.c:31: phase += 1;
	ld	hl, (_phase)
	inc	hl
	ld	(_phase), hl
;bintr.c:32: nmi_trig = 0;
	ld	0 (iy), #0x00
;bintr.c:35: print ("Final interrupt\n");
	ld	hl, #___str_0
	push	hl
	call	_print
	pop	af
;bintr.c:36: intr_cntdwn = 32;
	ld	a, #0x20
	out	(_intr_cntdwn), a
;bintr.c:37: nmi_cntdwn = 0;
	ld	a, #0x00
	out	(_nmi_cntdwn), a
	ret
00103$:
;bintr.c:39: nmi_cntdwn = 32;
	ld	a, #0x20
	out	(_nmi_cntdwn), a
;bintr.c:41: }
;bintr.c:42: }
	ret
___str_0:
	.ascii "Final interrupt"
	.db 0x0a
	.db 0x00
;bintr.c:44: void isr (void)
;	---------------------------------
; Function isr
; ---------------------------------
_isr::
;bintr.c:46: triggers++;
	ld	hl, #_triggers+0
	inc	(hl)
;bintr.c:48: switch (phase) {
	ld	iy, #_phase
	ld	a, 0 (iy)
	or	a, a
	or	a, 1 (iy)
	jr	Z,00101$
	ld	a, 0 (iy)
	sub	a, #0x02
	or	a, 1 (iy)
	jr	Z,00105$
	ret
;bintr.c:50: case 0 :
00101$:
;bintr.c:51: if (triggers > 5) {
	ld	a, #0x05
	ld	iy, #_triggers
	sub	a, 0 (iy)
	jr	NC,00103$
;bintr.c:52: phase += 1;
	ld	hl, (_phase)
	inc	hl
	ld	(_phase), hl
;bintr.c:53: triggers = 0;
	ld	0 (iy), #0x00
;bintr.c:54: intr_cntdwn = 0;
	ld	a, #0x00
	out	(_intr_cntdwn), a
;bintr.c:55: print ("Starting NMIs\n");
	ld	hl, #___str_1
	push	hl
	call	_print
	pop	af
;bintr.c:56: nmi_cntdwn = 64;
	ld	a, #0x40
	out	(_nmi_cntdwn), a
	ret
00103$:
;bintr.c:58: intr_cntdwn = 32;
	ld	a, #0x20
	out	(_intr_cntdwn), a
;bintr.c:61: break;
	ret
;bintr.c:64: case 2 :
00105$:
;bintr.c:65: intr_cntdwn = 0;
	ld	a, #0x00
	out	(_intr_cntdwn), a
;bintr.c:66: test_pass = 1;
	ld	hl,#_test_pass + 0
	ld	(hl), #0x01
;bintr.c:68: }
;bintr.c:69: }
	ret
___str_1:
	.ascii "Starting NMIs"
	.db 0x0a
	.db 0x00
;bintr.c:71: int main ()
;	---------------------------------
; Function main
; ---------------------------------
_main::
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
	ld	hl, #0x0000
	ld	(_phase), hl
;bintr.c:83: print ("Starting interrupts\n");
	ld	hl, #___str_2
	push	hl
	call	_print
	pop	af
;bintr.c:84: intr_cntdwn = 64;
	ld	a, #0x40
	out	(_intr_cntdwn), a
;bintr.c:85: set_timeout (50000);
	ld	hl, #0xc350
	push	hl
	call	_set_timeout
	pop	af
;bintr.c:87: for (loop=0; loop<1024; loop++) {
	ld	hl, #0x0000
	ld	(_loop), hl
00107$:
;bintr.c:88: if (test_pass)
	ld	a,(#_test_pass + 0)
	or	a, a
	jr	NZ,00103$
;bintr.c:90: check = sim_ctl_port;
	in	a, (_sim_ctl_port)
;bintr.c:87: for (loop=0; loop<1024; loop++) {
	ld	hl, (_loop)
	inc	hl
	ld	(_loop), hl
	ld	a,(#_loop + 1)
	xor	a, #0x80
	sub	a, #0x84
	jr	C,00107$
00103$:
;bintr.c:93: if (test_pass)
	ld	a,(#_test_pass + 0)
	or	a, a
	jr	Z,00105$
;bintr.c:94: sim_ctl (SC_TEST_PASSED);
	ld	a, #0x01
	out	(_sim_ctl_port), a
	jr	00106$
00105$:
;bintr.c:96: sim_ctl (SC_TEST_FAILED);
	ld	a, #0x02
	out	(_sim_ctl_port), a
00106$:
;bintr.c:98: return 0;
	ld	hl, #0x0000
;bintr.c:99: }
	ret
___str_2:
	.ascii "Starting interrupts"
	.db 0x0a
	.db 0x00
	.area _CODE
	.area _INITIALIZER
	.area _CABS (ABS)
