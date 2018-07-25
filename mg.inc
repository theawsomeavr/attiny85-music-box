;----------------------------------------------------------;
; Melody Generator Include File


.equ	A2 = 0		;220Hz
.equ	B2 = 1
.equ	H2 = 2
.equ	C2 = 3
.equ	Cis2 = 4
.equ	D2 = 5
.equ	Dis2 = 6
.equ	E2 = 7
.equ	F2 = 8
.equ	Fis2 = 9
.equ	G2 = 10
.equ	Gis2 = 11
.equ	A3 = 12		;440Hz
.equ	B3 = 13
.equ	H3 = 14
.equ	C3 = 15
.equ	Cis3 = 16
.equ	D3 = 17
.equ	Dis3 = 18
.equ	E3 = 19
.equ	F3 = 20
.equ	Fis3 = 21
.equ	G3 = 22
.equ	Gis3 = 23
.equ	A4 = 24		;880Hz
.equ	B4 = 25
.equ	H4 = 26
.equ	C4 = 27
.equ	Cis4 = 28
.equ	D4 = 29
.equ	Dis4 = 30
.equ	E4 = 31
.equ	F4 = 32
.equ	Fis4 = 33
.equ	G4 = 34
.equ	Gis4 = 35
.equ	A5 = 36		;1760Hz
.equ	B5 = 37
.equ	H5 = 38
.equ	C5 = 39
.equ	Cis5 = 40
.equ	D5 = 41
.equ	Dis5 = 42
.equ	E5 = 43
.equ	F5 = 44
.equ	Fis5 = 45
.equ	G5 = 46
.equ	Gis5 = 47
.equ	A6 = 48		;3520Hz
.equ	B6 = 49
.equ	H6 = 50
.equ	C6 = 51
.equ	Cis6 = 52
.equ	D6 = 53
.equ	Dis6 = 54
.equ	E6 = 55

.equ	EoS = 255	;End of score
.equ	en = 128	;End of line flag


;--------------------------------------------------------------------;
; T0 = int8(EL) x .uint8(EH), 32clks

.macro MULT
	mov	T0H, EL
	sbrc	EL, 7
	neg	EL

	clr	T0L
	sbrc	EH, 0
	add	T0L, EL
	lsr	T0L
	sbrc	EH, 1
	add	T0L, EL
	lsr	T0L
	sbrc	EH, 2
	add	T0L, EL
	lsr	T0L
	sbrc	EH, 3
	add	T0L, EL
	clr	T0L
	sbrc	EH, 4
	add	T0L, EL
	lsr	T0L
	sbrc	EH, 5
	add	T0L, EL
	lsr	T0L
	sbrc	EH, 6
	add	T0L, EL
	lsr	T0L
	sbrc	EH, 7
	add	T0L, EL

	lsl	T0H
	mov	T0H, _0
	brcc	PC+3
	neg	T0L
	sbc	T0H, T0H
.endm

