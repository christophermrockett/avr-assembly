;***********************************************************
;*	This is the skeleton file for Lab 4 of ECE 375
;*
;*	 Author: Chris Rockett
;*	   Date: 2/4/2025
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	mpr2 = r19
.def	rlo = r0				; Low byte of MUL result
.def	rhi = r1				; High byte of MUL result
.def	zero = r2				; Zero register, set to zero in INIT, useful for calculations
.def	A = r3					; A variable
.def	B = r4					; Another variable

.def	oloop = r17				; Outer Loop Counter
.def	iloop = r18				; Inner Loop Counter


;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;-----------------------------------------------------------
; Interrupt Vectors
;-----------------------------------------------------------
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0056					; End of Interrupt Vectors

;-----------------------------------------------------------
; Program Initialization
;-----------------------------------------------------------
INIT:							; The initialization routine

		; Initialize Stack Pointer
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

		clr		zero			; Set the zero register to zero, maintain
										; these semantics, meaning, don't
										; load anything else into it.

;-----------------------------------------------------------
; Main Program
;-----------------------------------------------------------
MAIN:							; The Main program

		rcall ADDLoad ; Call function to load ADD16 operands
		nop ; Check load ADD16 operands (Set Break point here #1)

		; Call ADD16 function to display its results (calculate FCBA + FFFF) = 01FCB9
		rcall ADD16
		nop ; Check ADD16 result (Set Break point here #2)


		rcall SUBLoad ; Call function to load SUB16 operands
		nop ; Check load SUB16 operands (Set Break point here #3)

		rcall SUB16 ; Call SUB16 function to display its results (calculate FCB9 - E420) = 1899
		nop ; Check SUB16 result (Set Break point here #4)


		rcall MULLoad; Call function to load MUL24 operands
		nop ; Check load MUL24 operands (Set Break point here #5)

		rcall MUL24; Call MUL24 function to display its results (calculate FFFFFF * FFFFFF) = FFFFFE000001
		nop ; Check MUL24 result (Set Break point here #6)

		rcall COMPOUNDLoad; Setup the COMPOUND function direct test
		nop ; Check load COMPOUND operands (Set Break point here #7)

		rcall COMPOUND; Call the COMPOUND function (calculate FE53^2 = FCA8CEE9)
		nop ; Check COMPOUND result (Set Break point here #8)

DONE:	rjmp	DONE			; Create an infinite while loop to signify the
								; end of the program.

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func: ADD16
; Desc: Adds two 16-bit numbers and generates a 24-bit number
;       where the high byte of the result contains the carry
;       out bit.
;-----------------------------------------------------------
ADDLoad:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;		
		; Execute the function here

		ldi		ZL, low(OperandA<<1)	; Load low byte of address
		ldi		ZH, high(OperandA<<1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(ADD16_OP1)	; Load low byte of address
		ldi		YH, high(ADD16_OP1)	; Load high byte of address

		lpm		mpr, z+	; Load low byte of A to mpr
		st		y+, mpr	; Store low byte of A to OP1 low address
		lpm		mpr, z	; Load high byte of A to mpr
		st		y, mpr	; Store high byte of A to OP1 high address

		ldi		ZL, low(OperandB<<1)	; Load low byte of address
		ldi		ZH, high(OperandB<<1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(ADD16_OP2)	; Load low byte of address
		ldi		YH, high(ADD16_OP2)	; Load high byte of address

		lpm		mpr, z+	; Load low byte of B to mpr
		st		y+, mpr	; Store low byte of B to OP2 low address
		lpm		mpr, z	; Load high byte of B to mpr
		st		y, mpr	; Store high byte of B to OP2 high address

		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret

ADD16:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr					
		push	mpr2		; Save mpr2 register

		; Load beginning address of first operand into X
		ldi		XL, low(ADD16_OP1)	; Load low byte of address
		ldi		XH, high(ADD16_OP1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(ADD16_OP2)	; Load low byte of address
		ldi		YH, high(ADD16_OP2)	; Load high byte of address

		; Load beginning address of result into Z
		ldi		ZL, low(ADD16_Result) ; Load low byte of address
		ldi		ZH, high(ADD16_Result) ; Load high byte of address

		; Execute the function
		ld		mpr, x+ ; load x LSB low value to mpr register
		ld		mpr2, y+ ; load y LSB low value to mpr2 register
		add		mpr2, mpr ; add x and y values and send to mpr2 register
		st		z+, mpr2 ; store addition result to z address
		ld		mpr, x ; load x high value and send to mpr register
		ld		mpr2, y ; load y high value and send to mpr register
		adc		mpr2, mpr ; add values with carry
		st		z+, mpr2 ; stores addition result to increased z address
		brcc	EXIT ; Checks if carry flag raised or not
		st		z, XH ; stores carry bit to increased z address (0 or 1)

EXIT:
		pop		mpr2						; Pops old mpr2 value
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: SUB16
; Desc: Subtracts two 16-bit numbers and generates a 16-bit
;       result. Always subtracts from the bigger values.
;-----------------------------------------------------------
SUBLoad:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;		
		; Execute the function here

		ldi		ZL, low(OperandC<<1)	; Load low byte of address
		ldi		ZH, high(OperandC<<1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(SUB16_OP1)	; Load low byte of address
		ldi		YH, high(SUB16_OP1)	; Load high byte of address

		lpm		mpr, z+	; Load low byte of C to mpr
		st		y+, mpr	; Store low byte of C to low address
		lpm		mpr, z	; Load high byte of C to mpr
		st		y, mpr	; Store high byte of C to high address

		ldi		ZL, low(OperandD<<1)	; Load low byte of address
		ldi		ZH, high(OperandD<<1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(SUB16_OP2)	; Load low byte of address
		ldi		YH, high(SUB16_OP2)	; Load high byte of address

		lpm		mpr, z+	; Load low byte of D to mpr
		st		y+, mpr	; Store low byte of D to low address
		lpm		mpr, z	; Load high byte of D to mpr
		st		y, mpr	; Store high byte of D to high address

		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret
SUB16:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;		; Execute the function here
		push	mpr2		; Save mpr2 register
	
		; Load beginning address of first operand into X
		ldi		XL, low(SUB16_OP1)	; Load low byte of address
		ldi		XH, high(SUB16_OP1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(SUB16_OP2)	; Load low byte of address
		ldi		YH, high(SUB16_OP2)	; Load high byte of address

		; Load beginning address of result into Z
		ldi		ZL, low(SUB16_Result) ; Load low byte of address
		ldi		ZH, high(SUB16_Result) ; Load high byte of address

		; Execute the function here
		ld		mpr, x+ ; load x LSB low value to mpr register
		ld		mpr2, y+ ; load y LSB low value to mpr2 register
		sub		mpr, mpr2 ; subtract x and y values and send to mpr register
		st		z+, mpr ; store subtraction result to z address
		ld		mpr, x ; load x high value and send to mpr register
		ld		mpr2, y ; load y high value and send to mpr register
		sbc		mpr, mpr2 ; subtract values with carry and send to mpr
		st		z+, mpr ; stores subtraction result to increased z address

		pop		mpr2
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: MUL24
; Desc: Multiplies two 24-bit numbers and generates a 48-bit
;       result.
;-----------------------------------------------------------
MULLoad:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;		
		; Execute the function here

		ldi		ZL, low(OperandE1<<1)	; Load low byte of address
		ldi		ZH, high(OperandE1<<1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(MUL24_OP1)	; Load low byte of address
		ldi		YH, high(MUL24_OP1)	; Load high byte of address

		lpm		mpr, z+	; Load low byte of E to mpr
		st		y+, mpr	; Store low byte of E to low address
		lpm		mpr, z	; Load high byte of E to mpr
		st		y+, mpr	; Store high byte of E to high address

		ldi		ZL, low(OperandE2<<1)	; Load low byte of address
		ldi		ZH, high(OperandE2<<1)	; Load high byte of address

		lpm		mpr, z	; Load 3rd byte to mpr
		st		y, mpr	; Store 3rd byte to OP1

		ldi		ZL, low(OperandF1<<1)	; Load low byte of address
		ldi		ZH, high(OperandF1<<1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(MUL24_OP2)	; Load low byte of address
		ldi		YH, high(MUL24_OP2)	; Load high byte of address

		lpm		mpr, z+	; Load low byte of F to mpr
		st		y+, mpr	; Store low byte of F to low address
		lpm		mpr, z	; Load high byte of F to mpr
		st		y+, mpr	; Store high byte of F to high address

		ldi		ZL, low(OperandF2<<1)	; Load low byte of address
		ldi		ZH, high(OperandF2<<1)	; Load high byte of address

		lpm		mpr, z	; Load 3rd byte to mpr
		st		y, mpr	; Store 3rd byte to OP2

		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value
		ret

MUL24:
;* - Simply adopting MUL16 ideas to MUL24 will not give you steady results. You should come up with different ideas.
		; Execute the function here
		push 	A				; Save A register
		push	B				; Save B register
		push	rhi				; Save rhi register
		push	rlo				; Save rlo register
		push	zero			; Save zero register
		push	XH				; Save X-ptr
		push	XL
		push	YH				; Save Y-ptr
		push	YL
		push	ZH				; Save Z-ptr
		push	ZL
		push	oloop			; Save counters
		push	iloop

		; Set Y to beginning address of B
		ldi		YL, low(MUL24_OP2)	; Load low byte
		ldi		YH, high(MUL24_OP2)	; Load high byte

		; Set Z to begginning address of resulting Product
		ldi		ZL, low(MUL24_Result)	; Load low byte
		ldi		ZH, high(MUL24_Result); Load high byte

		; Begin outer for loop
		ldi		oloop, 3		; Load counter
MUL24_OLOOP:
		; Set X to beginning address of A
		ldi		XL, low(MUL24_OP1)	; Load low byte
		ldi		XH, high(MUL24_OP1)	; Load high byte

		; Begin inner for loop
		ldi		iloop, 3		; Load counter
MUL24_ILOOP:
		ld		A, X+			; Get byte of A operand
		ld		B, Y			; Get byte of B operand
		mul		A,B				; Multiply A and B
		ld		A, Z+			; Get a result byte from memory
		ld		B, Z+			; Get the next result byte from memory
		add		rlo, A			; rlo <= rlo + A
		adc		rhi, B			; rhi <= rhi + B + carry
		ld		A, Z+			; Get a third byte from the result
		adc		A, zero			; Add carry to A
		ld		B, Z
		adc		B, zero
		st		Z, B
		st		-Z, A			; Store third byte to memory
		st		-Z, rhi			; Store second byte to memory
		st		-Z, rlo			; Store first byte to memory
		adiw	ZH:ZL, 1		; Z <= Z + 1
		dec		iloop			; Decrement counter
		brne	MUL24_ILOOP		; Loop if iLoop != 0
		; End inner for loop

		sbiw	ZH:ZL, 2		; Z <= Z - 1
		adiw	YH:YL, 1		; Y <= Y + 1
		dec		oloop			; Decrement counter
		brne	MUL24_OLOOP		; Loop if oLoop != 0
		; End outer for loop

		pop		iloop			; Restore all registers in reverves order
		pop		oloop
		pop		ZL
		pop		ZH
		pop		YL
		pop		YH
		pop		XL
		pop		XH
		pop		zero
		pop		rlo
		pop		rhi
		pop		B
		pop		A
		ret						; End a function with RET


;-----------------------------------------------------------
; Func: COMPOUND
; Desc: Computes the compound expression ((G - H) + I)^2
;       by making use of SUB16, ADD16, and MUL24.
;
;       D, E, and F are declared in program memory, and must
;       be moved into data memory for use as input operands.
;
;       All result bytes should be cleared before beginning.
;-----------------------------------------------------------
COMPOUNDLoad:
		ldi		ZL, low(OperandG<<1)	; Load low byte of address
		ldi		ZH, high(OperandG<<1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(SUB16_OP1)	; Load low byte of address
		ldi		YH, high(SUB16_OP1)	; Load high byte of address

		lpm		mpr, z+
		st		y+, mpr
		lpm		mpr, z
		st		y, mpr

		ldi		ZL, low(OperandH<<1)	; Load low byte of address
		ldi		ZH, high(OperandH<<1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(SUB16_OP2)	; Load low byte of address
		ldi		YH, high(SUB16_OP2)	; Load high byte of address

		lpm		mpr, z+
		st		y+, mpr
		lpm		mpr, z
		st		y, mpr

		ldi		ZL, low(OperandI<<1)	; Load low byte of address
		ldi		ZH, high(OperandI<<1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(ADD16_OP2)	; Load low byte of address
		ldi		YH, high(ADD16_OP2)	; Load high byte of address

		lpm mpr, z+
		st	y+, mpr
		lpm	mpr, z
		st	y, mpr
		ret 

COMPOUND:

		; Setup SUB16 with operands G and H

		; Perform subtraction to calculate G - H
		rcall SUB16
		; Setup the ADD16 function with SUB16 result and operand I
		ldi		ZL, low(SUB16_RESULT)	; Load low byte of address
		ldi		ZH, high(SUB16_RESULT)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(ADD16_OP1)	; Load low byte of address
		ldi		YH, high(ADD16_OP1)	; Load high byte of address

		ld	mpr, z+
		st	y+, mpr
		ld	mpr, z
		st	y, mpr

		ldi	ZL, low(ADD16_Result)
		ldi	ZH, high(ADD16_Result)
		ldi	iloop, 3
		clr mpr
CLRADD:
		st	z+, mpr
		dec iloop
		brne CLRADD

		; Perform addition next to calculate (G - H) + I
		rcall	ADD16
		; Setup the MUL24 function with ADD16 result as both operands
		ldi		ZL, low(ADD16_RESULT)	; Load low byte of address
		ldi		ZH, high(ADD16_RESULT)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(MUL24_OP1)	; Load low byte of address
		ldi		YH, high(MUL24_OP1)	; Load high byte of address

		ld	mpr, z+
		st	y+, mpr
		ld	mpr, z+
		st	y+, mpr
		ld	mpr, z
		st	y, mpr

		ldi		ZL, low(ADD16_RESULT)	; Load low byte of address
		ldi		ZH, high(ADD16_RESULT)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(MUL24_OP2)	; Load low byte of address
		ldi		YH, high(MUL24_OP2)	; Load high byte of address

		ld	mpr, z+
		st	y+, mpr
		ld	mpr, z+
		st	y+, mpr
		ld	mpr, z
		st	y, mpr

		ldi	ZL, low(MUL24_Result)
		ldi	ZH, high(MUL24_Result)
		clr	mpr
		ldi iloop, 6
CLRLOOP:
		st	Z+, mpr
		dec	iloop
		brne	CLRLOOP

		; Perform multiplication to calculate ((G - H) + I)^2
		rcall MUL24
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: MUL16
; Desc: An example function that multiplies two 16-bit numbers
;       A - Operand A is gathered from address $0101:$0100
;       B - Operand B is gathered from address $0103:$0102
;       Res - Result is stored in address
;             $0107:$0106:$0105:$0104
;       You will need to make sure that Res is cleared before
;       calling this function.
;-----------------------------------------------------------
MUL16:
		push 	A				; Save A register
		push	B				; Save B register
		push	rhi				; Save rhi register
		push	rlo				; Save rlo register
		push	zero			; Save zero register
		push	XH				; Save X-ptr
		push	XL
		push	YH				; Save Y-ptr
		push	YL
		push	ZH				; Save Z-ptr
		push	ZL
		push	oloop			; Save counters
		push	iloop

		clr		zero			; Maintain zero semantics

		; Set Y to beginning address of B
		ldi		YL, low(addrB)	; Load low byte
		ldi		YH, high(addrB)	; Load high byte

		; Set Z to begginning address of resulting Product
		ldi		ZL, low(LAddrP)	; Load low byte
		ldi		ZH, high(LAddrP); Load high byte

		; Begin outer for loop
		ldi		oloop, 2		; Load counter
MUL16_OLOOP:
		; Set X to beginning address of A
		ldi		XL, low(addrA)	; Load low byte
		ldi		XH, high(addrA)	; Load high byte

		; Begin inner for loop
		ldi		iloop, 2		; Load counter
MUL16_ILOOP:
		ld		A, X+			; Get byte of A operand
		ld		B, Y			; Get byte of B operand
		mul		A,B				; Multiply A and B
		ld		A, Z+			; Get a result byte from memory
		ld		B, Z+			; Get the next result byte from memory
		add		rlo, A			; rlo <= rlo + A
		adc		rhi, B			; rhi <= rhi + B + carry
		ld		A, Z			; Get a third byte from the result
		adc		A, zero			; Add carry to A
		st		Z, A			; Store third byte to memory
		st		-Z, rhi			; Store second byte to memory
		st		-Z, rlo			; Store first byte to memory
		adiw	ZH:ZL, 1		; Z <= Z + 1
		dec		iloop			; Decrement counter
		brne	MUL16_ILOOP		; Loop if iLoop != 0
		; End inner for loop

		sbiw	ZH:ZL, 1		; Z <= Z - 1
		adiw	YH:YL, 1		; Y <= Y + 1
		dec		oloop			; Decrement counter
		brne	MUL16_OLOOP		; Loop if oLoop != 0
		; End outer for loop

		pop		iloop			; Restore all registers in reverves order
		pop		oloop
		pop		ZL
		pop		ZH
		pop		YL
		pop		YH
		pop		XL
		pop		XH
		pop		zero
		pop		rlo
		pop		rhi
		pop		B
		pop		A
		ret						; End a function with RET

;***********************************************************
;*	Stored Program Data
;*	Do not  section.
;***********************************************************
; ADD16 operands
OperandA:
	.DW 0xFCBA
OperandB:
	.DW 0xFFFF

; SUB16 operands
OperandC:
	.DW 0XFCB9
OperandD:
	.DW 0XE420

; MUL24 operands
OperandE1:
	.DW	0XFFFF
OperandE2:
	.DW	0X00FF
OperandF1:
	.DW	0XFFFF
OperandF2:
	.DW	0X00FF

; Compoud operands
OperandG:
	.DW	0xFCBA				; test value for operand G
OperandH:
	.DW	0x2022				; test value for operand H
OperandI:
	.DW	0x21BB				; test value for operand I

;***********************************************************
;*	Data Memory Allocation
;***********************************************************
.dseg
.org	$0100				; data memory allocation for MUL16 example
addrA:	.byte 2
addrB:	.byte 2
LAddrP:	.byte 4

; Below is an example of data memory allocation for ADD16.
; Consider using something similar for SUB16 and MUL24.
.org	$0110				; data memory allocation for operands
ADD16_OP1:
		.byte 2				; allocate two bytes for first operand of ADD16
ADD16_OP2:
		.byte 2				; allocate two bytes for second operand of ADD16

.org	$0120				; data memory allocation for results
ADD16_Result:
		.byte 3				; allocate three bytes for ADD16 result

.org	$0130
SUB16_OP1:
		.byte 2
SUB16_OP2:
		.byte 2

.org	$0140
SUB16_Result:
		.byte 2

.org	$0150
MUL24_OP1:
		.byte 3

MUL24_OP2:
		.byte 3

.org	$0160
MUL24_Result:
		.byte 6

;***********************************************************
;*	Additional Program Includes
;***********************************************************
; There are no additional file includes for this program
