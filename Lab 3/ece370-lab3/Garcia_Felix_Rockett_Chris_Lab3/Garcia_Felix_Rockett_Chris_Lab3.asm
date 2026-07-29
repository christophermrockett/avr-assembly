;***********************************************************
;*	This is the skeleton file for Lab 3 of ECE 370
;*
;*	 Author: Chris Rockett
;*	   Date: 1/28/2026
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register is required for LCD Driver
.def	i = r17					; Loop i register
.def	sr = r18				; Scroll register 
.def	waitcnt = r19				; Wait Loop Counter
.def	ilcnt = r23				; Inner Loop Counter for WAIT command
.def	olcnt = r24				; Outer Loop Counter for WAIT command

.equ	WTime = 25				; Wait time in mS

.equ	ButtClr = 4				; Clear Button Input
.equ	ButtName = 5				; Name Button Input
.equ	ButtScroll = 7				; Scroll Button Input



;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp INIT				; Reset interrupt

.org	$0056					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:							; The initialization routine
		; Initialize Stack Pointer
			ldi		mpr, low(RAMEND)
			out		SPL, mpr		; Load SPL with low byte of RAMEND
			ldi		mpr, high(RAMEND)
			out		SPH, mpr		; Load SPH with high byte of RAMEND
		; Initialize LCD Display
			rcall	LCDInit			; Initializes LCD
			rcall	LCDClr			; Clears dots on LCD
		; Initialize Port D for input
			ldi		mpr, $00		; Set Port D Data Direction Register
			out		DDRD, mpr		; for input
			ldi		mpr, $FF		; Initialize Port D Data Register
			out		PORTD, mpr		; so all Port D inputs are Tri-State
		; NOTE that there is no RET or RJMP from INIT,
		; this is because the next instruction executed is the
		; first instruction of the main program

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:							; The Main program
		; Main function design is up to you. Below is an example to brainstorm.
			in		mpr, PIND		; Get button input from Port D
			andi	mpr, (0b10110000)	; Sets inputs and outputs for buttons (Active Low)
			cpi		mpr, (0b10100000)	; Check for ButtClr input (Recall Active Low)
			brne	NEXT			; Continue with next check
			rcall	Clear			; Call the subroutine Clear
			rjmp	MAIN			; Continue with program
NEXT:		cpi		mpr, (0b10010000) ; Check for ButtName input (Recall Active Low) 
			brne	NEXT2			; Continue with next check
			rcall	DisplayName		; Call the subroutine DisplayName
			rjmp	MAIN			; Continue with program
NEXT2:		cpi		mpr, (0b00110000) ; Check for ButtScroll input (Recall Active Low)
			brne	MAIN			; Continue with next check
			rcall	Scroll			; Call the subroutine Scroll
			rjmp	MAIN			; Continue with program
	
								; jump back to main and create an infinite
								; while loop.  Generally, every main program is an
								; infinite while loop, never let the main program
								; just run off

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;----------------------------------------------------------------
; Sub:	DisplayName
; Desc:	Sets LCD to display words from program memory
;		
;----------------------------------------------------------------
DisplayName:
		; Save variables by pushing them to the stack
		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;		; Execute the function here

		rcall	LCDBacklightOn				; LCD Backlight on
		rcall	CLRDM1						; Clears both lines with spaces
		rcall	CLRDM2
		ldi		ZL, low(STRING_BEG<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(STRING_BEG<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		YL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		YH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		Y+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP						; Keeps going though loop till i is 0

		ldi		YL, low($0110)				; Initializes Y pointer address to beginning of second line
		ldi		YH, high($0110)
		ldi		ZL, low(STRING_END<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(STRING_END<<1)		; Gets address of higher Beginning String data stores to pointer Z



		ldi		i, 16						; Sets loop number
LOOP2:
		lpm		mpr, z+						; Sends new x data to mpr register
		st		Y+, mpr						; mpr data stored into Y pointer then increases
		dec		i							; Decrements i
		brne	LOOP2						; Keeps going through loop till i is 0
		
		rcall	LCDWrite					; X and Y data onto LCD because of their addresses

		
		; Restore variables by popping them from the stack,
		; in reverse order
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		waitcnt						; Pops old waitcnt value
		pop		mpr							; Pops old mpr value

		ret						; End a function with RET

;----------------------------------------------------------------
; Sub:	Clear
; Desc:	Clears the LCD screen and turns the back light off
;		
;----------------------------------------------------------------
Clear:						
		; Execute the function here
		rcall	LCDClr			; Clears LCD screen
		rcall	LCDBacklightOff	; Turns LCD backlight off

		ret						; End a function with RET

;----------------------------------------------------------------
; Sub:	Scroll
; Desc:	Scrolls text on LCD screen where the first line goes to 
;		the second line, while the second goes to the first.
;----------------------------------------------------------------
Scroll:
		; Save variables by pushing them to the stack
		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;		; Execute the function here
		push	sr

		; Execute the function here
		ldi		YL, low($011F)		; Load end of address for LCD
		ldi		YH, high($011F)		

		ldi		i, 31				; Initializes loop number

		; Loop to push letters to stack, starting from 2nd to last letter
LOOP3:
		ld		sr, -Y		; Load second to last letter address to sr register
		push	sr			; Push to stack
		dec		i			; Decrement i
		brne	LOOP3

		ldi		YL, low($011F)		; Load end of address for 2nd line LCD
		ldi		YH, high($011F)		

		ld		sr, Y		; Push last letter to top of stack
		push	sr

		ldi		YL, low($0100)		; Load beginning LCD address
		ldi		YH, high($0100)

		ldi		i, 32			; Initializes loop number

		; Loop to write letters from stack order to LCD address + 1
LOOP4:
		pop		sr							; Pops SR from stack
		st		Y+, sr						; Stores top of stack (last letter) to beginning address of Y
		dec		i							; Decrements Loop
		brne	LOOP4

		ldi		waitcnt, WTime				; Delays writing new addresses to LCD by .25 S
		rcall	WAIT



		rcall	LCDWrite					; X and Y data onto LCD because of their addresses


		pop		sr
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		waitcnt						; Pops old waitcnt value
		pop		mpr							; Pops old mpr value



		ret						; End a function with RET
;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly
;		waitcnt*10ms.  Just initialize wait for the specific amount
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			(((((3*ilcnt)-1+4)*olcnt)-1+4)*waitcnt)-1+16
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

LoopW:	ldi		olcnt, 224		; load olcnt register
OLoopW:	ldi		ilcnt, 237		; load ilcnt register
ILoopW:	dec		ilcnt			; decrement ilcnt
		brne	ILoopW			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoopW			; Continue Outer Loop
		dec		waitcnt		; Decrement wait
		brne	LoopW			; Continue Wait loop

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING_BEG:
.DB		"Felix Garcia    "		; Declaring data in ProgMem
STRING_END:
.DB		"Chris Rockett   "
;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
