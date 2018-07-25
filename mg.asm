;----------------------------------------------------------;
; Melody Generator  (C)ChaN, 2005


.include "tn45def.inc"	;This is included in "Atmel AVR Studio"
.include "avr.inc"
.include "mg.inc"

.def	_0	= r15
.def	_Sreg	= r14
.def	_Zreg	= r12
.def	_Yreg	= r10
.def	_TmrH	= r9
.def	_TmrL	= r8
.def	_TmrS	= r7

.equ	N_NOTE	= 6


;----------------------------------------------------------;
; Work Area

.dseg
	.org	RAMTOP
NoteIdx:.byte	1	; Note rotation index

Notes:	.byte	(2+3+1+1+1+1)*N_NOTE
.equ	ns_freq = 0	;Angular Speed
.equ	ns_rptr = 2	;Wave table read pointer (16.8 fraction)
.equ	ns_lvl = 5	;Level
.equ	ns_wrap = 6	;Loop Flag
.equ	ns_loop = 7	;Loop Count
.equ	ns_lp = 8	;Level Pointer
.equ	nsize = 9	;size of this structure


;----------------------------------------------------------;
; Program Code

.cseg
	; Interrupt Vectors (ATtiny45)
	rjmp	reset		; Reset
	rjmp	0		; INT0
	rjmp	0		; PCINT0
	rjmp	0		; TC1_COMA
	rjmp	0		; TC1_OVF
	rjmp	0		; TC0_OVF
	rjmp	0		; EE_RDY
	rjmp	0		; ANA_COMP
	rjmp	0		; ADC
	rjmp	0		; TC1_COMB
	rjmp	isr_tc0_coma	; TC0_COMA
;	rjmp	0		; TC0_COMB
;	rjmp	0		; WDT
;	rjmp	0		; USI_START
;	rjmp	0		; USI_OVF


;--------------------------------------------------------------------;
; Program Code

reset:
	clr	_0
	ldiw	X, RAMTOP		;Clear RAM
	ldi	AL, 0			;
	st	X+, _0			;
	dec	AL			;
	brne	PC-2			;/

;	outi	OSCCAL, 172		;Adjust OSCCAL if needed.

	outi	PORTB, 0b001101		;Initalize Port B
	outi	DDRB,  0b010010		;/

	outi	PLLCSR, 0b00000110	;Initialize TC1 in 250 kHz fast PWM mode.
	outi	TCCR1,  0b01100001	;Connect TC1 to OC1A
	outi	GTCCR,  0b01100000	;Connect TC1 to OC1B

	outi	OCR0A, 62		;Initalize TC0 in 32 kHz interval timer.
	outi	TCCR0A, 0b00000010
	outi	TCCR0B, 0b00000010
	outi	TIMSK, (1<<OCIE0A)


start_play:
	ldiw	Z, score*2
	cli
	clrw	_Tmr
	clr	_TmrS
	sei

pl_next:
	lpmw	B, Z+
	 rcall	drv_decay
	cli
	cpw	_Tmr, B
	sei
	brcs	PC-5

pl_note:
	lpm	CL, Z+
	cpi	CL, EoS
	breq	start_play
	mov	AL, CL
	 rcall	note_on
	andi	CL, en
	breq	pl_note
	rjmp	pl_next



;--------------------------------------------------------------------;
; Note ON
;
;Call: AL[6:0] = key number

note_on:
	pushw	Z

	mov	ZL, AL
	lsl	ZL
	clr	ZH
	addiw	Z, tbl_pitch*2
	lpmw	A, Z+

	lds	YL, NoteIdx
	addi	YL, 9
	cpi	YL, 9*N_NOTE
	brcs	PC+2
	clr	YL
	sts	NoteIdx, YL
	clr	YH
	addiw	Y, Notes

	ldiw	B, wt_attack*2
	cli
	stdw	Y+ns_freq, A
	stdw	Y+ns_rptr+1, B
	sei
	stdi	Y+ns_lvl, 255
	std	Y+ns_wrap, AL
	std	Y+ns_loop, _0
	std	Y+ns_lp, _0

	popw	Z
	ret


;--------------------------------------------------------------------;
; Decay envelope generation

drv_decay:
	pushw	Z
	ldiw	Y, Notes
dd_lp:
	ldd	AL, Y+ns_wrap	;Has sustain loop not wrapped?
	ldi	AH, 255		;
	cp	AL, AH		;
	breq	dd_nxt		;/
	std	Y+ns_wrap, AH	;Clear wrapped flag.
	ldd	AL, Y+ns_loop
	inc	AL
	cpi	AL, 12
	brcs	PC+2
	ldi	AL, 0
	std	Y+ns_loop, AL
	brcs	dd_nxt
	ldd	ZL, Y+ns_lp
	inc	ZL
	breq	dd_nxt
	std	Y+ns_lp, ZL
	clr	ZH
	addiw	Z, envelope*2
	lpm	AL, Z
	std	Y+ns_lvl, AL
dd_nxt:	adiw	YL, 9
	cpi	YL, low(Notes+nsize*N_NOTE)
	brne	dd_lp

	popw	Z
	ret



;--------------------------------------------------------------------;
; 32 kHz wave form synthesising interrupt


isr_tc0_coma:
	in	_Sreg, SREG		;Save regs...
	movw	_Zreg, ZL		;
	movw	_Yreg, YL		;/

	ldiw	Y, Notes		;Process all notes
	clrw	T2			;Clear accumlator
tone_lp:
	ldd	EH, Y+ns_rptr		;Load wave table pointer
	lddw	Z, Y+ns_rptr+1		;/
	lpm	EL, Z			;Get a sample
	lddw	T4, Y+ns_freq		;Load angular speed
	add	EH, T4L			;Increase wave table ptr (next angle)
	adc	ZL, T4H			;
	adc	ZH, _0			;/
	cpi	ZH, high(wt_end*2)	;Repeat sustain area
	brcs	PC+4			;
	subiw	Z, (wt_end-wt_loop)*2	;
	std	Y+ns_wrap, _0		;/
	std	Y+ns_rptr, EH		;Save wave table ptr
	stdw	Y+ns_rptr+1, Z		;/
	ldd	EH, Y+ns_lvl		;Apply envelope curve
	MULT				;/
	addw	T2, T0			;Add the sample to accumlator
	adiw	YL, 9			;Next note
	cpi	YL, low(Notes+nsize*N_NOTE);
	brne	tone_lp			;/

	asrw	T2			;Divide it by 4
	asrw	T2			;/
	ldiw	E, 253			;Clip it between -255 to 253
	cpw	T2, E			;
	brlt	PC+2			;
	movw	T2L, EL			;
	ldiw	E, -255			;
	cpw	T2, E			;
	brge	PC+2			;
	movw	T2L, EL			;/
	asrw	T2			;Set it to PWM modulator
	ror	T2H			;
	mov	EL, T2L			;
	subi	EL, 0x80		;
	mov	EH, EL			;
	com	EH			;
	sbrc	T2H, 7			;
	inc	EL			;
	out	OCR1A, EL		;
	out	OCR1B, EH		;/

	sec				;Increment sequense timer
	adc	_TmrS, _0		;
	adc	_TmrL, _0		;
	adc	_TmrH, _0		;/

	movw	ZL, _Zreg		;Restore regs...
	movw	YL, _Yreg		;
	out	SREG, _Sreg		;/

	reti



;--------------------------------------------------------------------;
; Score table
;--------------------------------------------------------------------;

score:
.include "melody.asm"


;--------------------------------------------------------------------;
; Pitch number to angular speed conversion table
;--------------------------------------------------------------------;
;Since sustain area of wave table, a cycle of fundamental frequency, is sampled
;in 128 points, the base frequency becomes 32000/128 = 250 Hz. The wave table
;lookup pointer, 16.8 fraction, is increased every sample by these 8.8 fractional
;angular speed values.

tbl_pitch: ;  A     B     H     C    Cis    D    Dis    E     F    Fis    G    Gis 
	.dw  225,  239,  253,  268,  284,  301,  319,  338,  358,  379,  401,  425 ; 220Hz..
	.dw  451,  477,  506,  536,  568,  601,  637,  675,  715,  758,  803,  851 ; 440Hz..
	.dw  901,  955, 1011, 1072, 1135, 1203, 1274, 1350, 1430, 1515, 1606, 1701 ; 880Hz..
	.dw 1802, 1909, 2023, 2143, 2271, 2406, 2549, 2700, 2861, 3031, 3211, 3402 ; 1760Hz..
	.dw 3604, 3818, 4046, 4286, 4542, 4812, 5098, 5400			   ; 3520Hz


;--------------------------------------------------------------------;
; Envelope Table
;--------------------------------------------------------------------;

envelope:
	.db 255,252,250,247,245,243,240,238,235,233,231,228,226,224,222,219
	.db 217,215,213,211,209,207,205,203,201,199,197,195,193,191,189,187
	.db 185,183,182,180,178,176,174,173,171,169,168,166,164,163,161,159
	.db 158,156,155,153,152,150,149,147,146,144,143,141,140,139,137,136
	.db 134,133,132,130,129,128,127,125,124,123,122,120,119,118,117,116
	.db 115,113,112,111,110,109,108,107,106,105,104,103,102,101,100,99
	.db 98,97,96,95,94,93,92,91,90,89,88,87,87,86,85,84
	.db 83,82,82,81,80,79,78,78,77,76,75,75,74,73,72,72
	.db 71,70,69,69,68,67,67,66,65,65,64,64,63,62,62,61
	.db 60,60,59,59,58,57,57,56,56,55,55,54,54,53,53,52
	.db 51,51,50,50,49,49,48,48,48,47,47,46,46,45,45,44
	.db 44,43,43,43,42,42,41,40,40,39,39,38,38,37,37,36
	.db 35,35,34,34,33,33,32,31,31,30,30,29,29,28,28,27
	.db 26,26,25,25,24,24,23,22,22,21,21,20,20,19,19,18
	.db 17,17,16,16,15,15,14,13,13,12,12,11,11,10,10,9
	.db 8,8,7,7,6,6,5,4,4,3,3,2,2,1,1,0


;--------------------------------------------------------------------;
; Wave Table
;--------------------------------------------------------------------;
; 8bit, 32 ksps, 250 Hz fundamental frequency

	.org	3072/2	; Bottom stored

wt_attack: ; Attack area
	.db 0, 0, 0, 0, 0, 0, -1, -2, -2, -3, -2, -2, -1, 0, 0, 0
	.db 0, 0, -1, -2, -3, -3, -4, -4, -3, -2, -1, 0, 0, 1, 0, 0
	.db 0, -1, -2, -3, -3, -2, 0, 0, 2, 4, 5, 5, 5, 3, 1, 0
	.db -2, -3, -4, -3, -2, 0, 1, 2, 3, 2, 0, -2, -6, -11, -15, -18
	.db -19, -19, -16, -11, -5, 1, 8, 15, 20, 23, 24, 23, 20, 17, 13, 10
	.db 7, 6, 6, 8, 10, 13, 16, 18, 20, 20, 20, 19, 18, 18, 18, 18
	.db 19, 21, 24, 26, 27, 28, 27, 25, 22, 17, 11, 5, 0, -5, -9, -12
	.db -13, -13, -11, -9, -5, -1, 1, 4, 6, 6, 4, 0, -5, -12, -21, -30
	.db -39, -48, -56, -62, -66, -69, -70, -71, -70, -70, -70, -71, -72, -75, -77, -79
	.db -80, -78, -75, -69, -61, -50, -38, -26, -13, -2, 7, 15, 21, 25, 28, 30
	.db 33, 36, 40, 44, 49, 55, 59, 61, 62, 60, 56, 49, 42, 34, 27, 22
	.db 20, 21, 25, 33, 42, 52, 63, 72, 80, 86, 89, 90, 89, 87, 84, 81
	.db 79, 77, 75, 73, 72, 69, 66, 61, 55, 48, 39, 31, 22, 14, 6, 0
	.db -5, -10, -14, -17, -20, -22, -24, -26, -28, -29, -30, -31, -32, -33, -34, -35
	.db -36, -37, -39, -41, -44, -48, -52, -57, -63, -70, -77, -85, -94, -102, -110, -116
	.db -121, -124, -124, -121, -116, -109, -99, -89, -78, -68, -60, -53, -48, -45, -43, -43
	.db -43, -42, -41, -40, -37, -33, -29, -25, -22, -19, -17, -16, -15, -14, -12, -9
	.db -4, 2, 11, 22, 34, 46, 57, 67, 75, 81, 84, 86, 87, 86, 86, 85
	.db 85, 85, 86, 86, 87, 86, 84, 82, 78, 73, 69, 64, 60, 58, 56, 57
	.db 59, 62, 66, 70, 75, 79, 83, 86, 89, 91, 92, 92, 92, 90, 86, 81
	.db 73, 63, 52, 38, 24, 9, -5, -19, -31, -42, -50, -57, -61, -64, -66, -67
	.db -68, -68, -68, -67, -66, -64, -61, -56, -52, -46, -41, -36, -32, -29, -28, -28
	.db -30, -34, -39, -44, -50, -56, -62, -68, -74, -79, -84, -90, -95, -100, -104, -107
	.db -108, -108, -107, -103, -98, -92, -84, -76, -67, -58, -49, -40, -32, -24, -16, -8
	.db -1, 5, 11, 16, 20, 22, 22, 21, 18, 14, 10, 5, 1, -1, -3, -3
	.db -2, 0, 1, 5, 9, 12, 16, 20, 24, 28, 34, 40, 47, 55, 64, 72
	.db 81, 89, 96, 101, 105, 108, 108, 108, 107, 105, 103, 101, 100, 98, 96, 93
	.db 90, 87, 83, 79, 75, 70, 66, 62, 59, 56, 55, 53, 52, 51, 50, 48
	.db 46, 44, 42, 39, 37, 34, 31, 28, 24, 20, 15, 10, 3, -3, -12, -21
	.db -30, -39, -48, -57, -65, -72, -79, -85, -90, -95, -99, -103, -106, -109, -110, -112
	.db -112, -112, -111, -110, -109, -107, -106, -105, -104, -104, -103, -102, -101, -99, -97, -94
	.db -90, -86, -82, -78, -75, -72, -69, -67, -65, -63, -61, -58, -54, -50, -44, -38
	.db -31, -23, -16, -10, -4, 1, 6, 10, 14, 18, 23, 27, 32, 38, 43, 49
	.db 54, 59, 63, 67, 70, 73, 75, 77, 79, 81, 83, 85, 88, 91, 93, 96
	.db 99, 101, 103, 105, 107, 109, 110, 111, 112, 112, 112, 111, 109, 107, 104, 100
	.db 96, 92, 88, 83, 79, 75, 70, 65, 60, 55, 49, 43, 36, 30, 24, 18
	.db 12, 7, 3, 0, -3, -6, -8, -11, -14, -17, -20, -24, -28, -32, -37, -42
	.db -46, -51, -55, -59, -63, -67, -71, -75, -79, -82, -85, -88, -91, -93, -95, -97
	.db -98, -100, -101, -102, -103, -104, -104, -104, -103, -101, -99, -96, -93, -89, -86, -83
	.db -80, -78, -76, -75, -74, -73, -72, -71, -70, -68, -65, -63, -59, -56, -52, -48
	.db -44, -40, -35, -30, -24, -18, -11, -4, 3, 11, 19, 27, 34, 41, 48, 53
	.db 58, 63, 67, 71, 75, 79, 82, 86, 89, 92, 94, 95, 96, 97, 98, 98
	.db 99, 100, 101, 103, 105, 108, 110, 112, 114, 115, 115, 114, 113, 110, 107, 103
	.db 99, 95, 91, 87, 83, 79, 74, 70, 65, 59, 53, 47, 41, 35, 29, 24
	.db 19, 14, 11, 7, 4, 1, -1, -5, -9, -14, -19, -25, -31, -37, -43, -50
	.db -56, -62, -68, -73, -78, -83, -88, -92, -97, -101, -105, -109, -112, -115, -117, -119
	.db -120, -121, -120, -119, -118, -116, -114, -112, -109, -106, -104, -101, -99, -96, -94, -91
	.db -88, -85, -81, -78, -74, -70, -66, -62, -57, -53, -49, -45, -41, -37, -32, -27
	.db -22, -16, -10, -4, 1, 8, 14, 20, 25, 31, 36, 41, 46, 50, 55, 60
	.db 64, 69, 73, 77, 81, 85, 88, 90, 93, 95, 97, 99, 101, 103, 106, 109
	.db 112, 115, 118, 121, 123, 125, 126, 126, 125, 125, 123, 121, 119, 117, 115, 112
	.db 110, 107, 103, 99, 94, 89, 83, 76, 69, 62, 54, 47, 39, 31, 24, 16
	.db 9, 2, -4, -11, -18, -25, -31, -38, -44, -51, -57, -62, -68, -73, -79, -84
	.db -88, -93, -97, -102, -106, -109, -113, -116, -119, -121, -123, -124, -125, -126, -127, -127
	.db -127, -127, -126, -125, -125, -123, -122, -120, -118, -116, -114, -111, -107, -104, -100, -95
	.db -91, -86, -80, -75, -69, -63, -58, -52, -46, -40, -34, -28, -22, -16, -10, -4

wt_loop: ; Sustain area
	.db 0, 5, 11, 17, 23, 28, 34, 39, 45, 50, 55, 60, 65, 69, 74, 78
	.db 82, 85, 89, 92, 95, 98, 100, 102, 104, 106, 107, 109, 109, 110, 110, 111
	.db 110, 110, 109, 108, 107, 106, 104, 102, 100, 98, 95, 93, 90, 87, 83, 80
	.db 76, 72, 68, 64, 59, 55, 50, 46, 41, 36, 31, 26, 21, 15, 10, 5
	.db 0, -5, -10, -15, -21, -26, -31, -36, -41, -46, -50, -55, -59, -64, -68, -72
	.db -76, -80, -83, -87, -90, -93, -95, -98, -100, -102, -104, -106, -107, -108, -109, -110
	.db -110, -111, -110, -110, -109, -109, -107, -106, -104, -102, -100, -98, -95, -92, -89, -85
	.db -82, -78, -74, -69, -65, -60, -55, -50, -45, -39, -34, -28, -23, -17, -11, -5
wt_end:

