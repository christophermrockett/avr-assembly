;***********************************************************
;*	This is the skeleton file for Lab 5 of ECE 375
;*
;*	 Author: Chris Rockett
;*	   Date: 2/11/2026
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	waitcnt = r17			; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter
.def	i = r23					; i variable for loops
.def	LCNT = r24				; Left counter
.def	RCNT = r25				; Right counter

.equ	WTime = 100				; Time to wait in wait loop (1 second)

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	ButtClr = 3				; Clear Button Input
.equ	EngEnR = 5				; Right Engine Enable Bit
.equ	EngEnL = 6				; Left Engine Enable Bit
.equ	EngDirR = 4				; Right Engine Direction Bit
.equ	EngDirL = 7				; Left Engine Direction Bit

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////

.equ	MovFwd = (1<<EngDirR|1<<EngDirL)	; Move Forward Command
.equ	MovBck = $00				; Move Backward Command
.equ	TurnR = (1<<EngDirL)			; Turn Right Command
.equ	TurnL = (1<<EngDirR)			; Turn Left Command
.equ	Halt = (1<<EngEnR|1<<EngEnL)		; Halt Command

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0002					; INT0 interrupt (Right whisker hit)
		rcall	HitRight		; Goes through right whisker hit procedure
		reti

.org	$0004					; INT1 interrupt (Left whisker hit)
		rcall	HitLeft			; Goes through left whisker hit procedure
		reti

.org	$0008					; INT3 interrupt (Clear button hit)
		rcall	Clear			; Resets left and right counters and display
		reti

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

		; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low

		; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

		; Initialize LCD Display
		rcall	LCDInit			; Initializes LCD
		rcall	LCDClr			; Clears dots on LCD
		rcall	DisplayName		; Displays the initial count (0) on display

		; Initialize external interrupts
		ldi		mpr, 0b1000_1010	; Sets intterupts INT0, INT1, and INT3 to falling edge (10)
		sts		EICRA, mpr

		; Configure the External Interrupt Mask
		ldi		mpr, 0b0000_1011	; Configures interrupts INT0, INT1, and INT3
		out		EIMSK, mpr

		; Initialize Count variables to 0
		ldi LCNT, 0			
		ldi RCNT, 0

		; Turn on interrupts
			; NOTE: This must be the last thing to do in the INIT function
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:							; The Main program

		ldi		mpr, MovFwd		; Load Move Forward Command
		out		PORTB, mpr		; Send command to motors
		rjmp	MAIN			; Create an infinite while loop to signify the
								; end of the program.

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

		ldi		ZL, low(COUNT_LEFT<<1)		; Gets address of lower COUNT_LEFT data stores to pointer Z
		ldi		ZH, high(COUNT_LEFT<<1)		; Gets address of higher COUNT_LEFT data stores to pointer Z
		ldi		YL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		YH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 14						; Sets loop number equal to characters in COUNT_LEFT

LOOPD:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		Y+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOPD						; Keeps going though loop till i is 0

		ldi		YL, low($0110)				; Initializes Y pointer address to beginning of second line
		ldi		YH, high($0110)
		ldi		ZL, low(COUNT_RIGHT<<1)		; Gets address of lower COUNT_RIGHT data stores to pointer Z
		ldi		ZH, high(COUNT_RIGHT<<1)		; Gets address of COUNT_RIGHT data stores to pointer Z



		ldi		i, 14						; Sets loop number equal to characters in COUNT_RIGHT
LOOPD2:
		lpm		mpr, z+						; Sends new x data to mpr register
		st		Y+, mpr						; mpr data stored into Y pointer then increases
		dec		i							; Decrements i
		brne	LOOPD2						; Keeps going through loop till i is 0
		
		rcall	LCDWrite					; X and Y data onto LCD because of their addresses

		
		; Restore variables by popping them from the stack,
		; in reverse order
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		waitcnt						; Pops old waitcnt value
		pop		mpr							; Pops old mpr value

		ret						; End a function with RET

;----------------------------------------------------------------
; Sub:	HitRight
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------

HitRight:
		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		ldi		XL, low($011D)				; Gets address of lower 010D data stores to pointer Y for first line of LCD
		ldi		XH, high($011D)				; Gets address of higher 010D data stores to pointer Y for first line of LCD

		inc		RCNT			; Increments Right Count
		mov		mpr, RCNT		; Copies value to mpr for Bin2ASCII function
		rcall	Bin2ASCII		; Calls Bin2ASCII from LCDDriver file
		rcall	LCDWrite		; Updates new number to LCD screen

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn left for a second
		ldi		mpr, TurnL	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again
		ldi		mpr, MovFwd	; Load Move Forward command
		out		PORTB, mpr	; Send command to port

		ldi		mpr, 0b0000_1011	; Clears any interrupt queues
		out		EIFR, mpr

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr
		ret				; Return from subroutine

;----------------------------------------------------------------
; Sub:	HitLeft
; Desc:	Handles functionality of the TekBot when the left whisker
;		is triggered.
;----------------------------------------------------------------
HitLeft:
		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		ldi		XL, low($010C)				; Gets address of lower 010C data stores to pointer Y for first line of LCD
		ldi		XH, high($010C)				; Gets address of higher 010C data stores to pointer Y for first line of LCD

		inc		LCNT		; Increments Left Count
		mov		mpr, LCNT	; Copies value to mpr for Bin2ASCII function
		rcall	Bin2ASCII	; Calls Bin2ASCII from LCDDriver file
		rcall	LCDWrite	; Updates new number to LCD screen

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again
		ldi		mpr, MovFwd	; Load Move Forward command
		out		PORTB, mpr	; Send command to port

		ldi		mpr, 0b0000_1011	; Clears any interrupt queues
		out		EIFR, mpr

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr
		ret				; Return from subroutine

;----------------------------------------------------------------
; Sub:	Clear
; Desc:	Resets counter numbers and resets LCD display
;	
;----------------------------------------------------------------
Clear:
		ldi		LCNT, 0		; Resets counts to 0
		ldi		RCNT, 0

		rcall	LCDClr			; Resets LCD to display 0
		rcall	DisplayName

		ldi		mpr, 0b0000_1011	; Clears any interrupt queues
		out		EIFR, mpr

		ret



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

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait
		brne	Loop			; Continue Wait loop

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine

;***********************************************************
;*	Stored Program Data
;***********************************************************

COUNT_LEFT:
.DB		"Left Count: 0 "		; Declaring data in program memory
COUNT_RIGHT:
.DB		"Right Count: 0"

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver(1).asm"		; Include the LCD Driver
