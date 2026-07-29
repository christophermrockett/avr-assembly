;***********************************************************
;*
;*	This is the skeleton file for Lab 6 of ECE 375
;*
;*	 Author: Christopher Rockett
;*	   Date: 2/18/2025
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	spd = r17				; Speed register
.def	LED = r18				; LED register
.def	mpr2 = r19				; Other multipurpose register
.def	waitcnt = r20			; Wait Loop Counter
.def	ilcnt = r23				; Inner Loop Counter for WAIT command
.def	olcnt = r24				; Outer Loop Counter for WAIT command

.equ	WTime = 10				; Wait time in mS

.equ	IncrButt = 1			; Increment button input bit
.equ	DecrButt = 3			; Decrement button input bit
.equ	MaxButt = 0				; Max speed button input bit
.equ	EngEnR = 5				; right Engine Enable Bit
.equ	EngEnL = 6				; left Engine Enable Bit
.equ	EngDirR = 4				; right Engine Direction Bit
.equ	EngDirL = 7				; left Engine Direction Bit

.equ	MovFwd = (1<<EngDirR|1<<EngDirL)	; Move Forward Command
.equ	Halt = (1<<EngEnR|1<<EngEnL)		; Halt Command


;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

		; place instructions in interrupt vectors here, if needed

.org	$0002					; INT0 interrupt (Max Speed)
		rcall	SPEED_MAX		; Goes through MAX SPEED function
		reti

.org	$0004					; INT1 interrupt (Increment Speed)
		rcall	SPEED_UP		; Goes through increment function
		reti

.org	$0008					; INT3 interrupt (Decrement Speed)
		rcall	SPEED_DOWN		; Goes through decrement function
		reti

.org	$0056					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
		; Initialize the Stack Pointer
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

		; Configure I/O ports
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low

		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State


		; Configure External Interrupts, if needed
		ldi		mpr, 0b1000_1010	; Sets intterupts INT0, INT1, and INT3 to falling edge (10) (0-3, and 6-7 bits)
		sts		EICRA, mpr

		ldi		mpr, 0b0000_1011	; Configures interrupts INT0, INT1, and INT3 (0, 1, & 3 bits)
		out		EIMSK, mpr

		; Configure 16-bit Timer/Counter 1A and 1B
		; Fast PWM, 8-bit mode, no prescaling

		ldi		mpr, 0b11110001 ; Clear OC1A on compare match, set OC1A to top for A & B & inverting mode
		sts		TCCR1A, mpr

		ldi		mpr, 0b00001001 ; No prescaling 8-bit PWM set
		sts		TCCR1B, mpr

		; Set TekBot to Move Forward (1<<EngDirR|1<<EngDirL) on Port B
		; Set initial speed, display on Port B pins 3:0
		ldi		mpr, MovFwd		; Keeps constant move forward led's on
		out		PORTB, mpr
		clr		spd				; Sets initial speed to 0
		clr		mpr				; Clears junk values out of mpr
		sts OCR1AH, mpr			; Sets output compare inital registers to 0
		sts OCR1AL, spd
		sts OCR1BH, mpr
		sts OCR1BL, spd	
		; Enable global interrupts (if any are used)

		sei ; Turns on interrupts

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		rjmp	MAIN			; Constant program loop

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	SPEED_MAX
; Desc:	Sets speed to max speed and updates LED's based on 
;		speed.
;-----------------------------------------------------------
SPEED_MAX:	

		; If needed, save variables by pushing to the stack
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			

		ldi		waitcnt, WTime	; Wait 10ms to process singular button press
		rcall	Wait

		; Execute the function here
		ldi		spd, 0xFF			; Sets Max speed value to 255
		clr		mpr2				; Clear mpr2
		sts		OCR1AH, mpr2		; OCR1A for LED 5
		sts		OCR1AL, spd			; Sets register to max speed value (0 duty cycle)
		sts		OCR1BH, mpr2		; OCR1B for LED 6
		sts		OCR1BL, spd			; Sets register to max speed value (0 duty cycle)

		in		mpr, PORTB			; Grabs PORTB input
		andi	mpr, 0xF0			; Saves upper bit LED values (4-7 bits) for engine indicator
		mov		mpr2, spd			; Copy spd value to mpr2
		andi	mpr2, 0x0F			; Save lower bit LED values (0-3 bits) for speed level indicator
		or		mpr, mpr2			; Combines upper and lower bit LED values
		out		PORTB, mpr			; Displays new speed level and engine indicator values

		ldi		mpr, 0b0000_1011	; Clears any interrupt queues
		out		EIFR, mpr

		; Restore any saved variables by popping from stack
		pop		mpr		; Restore program state
		out		SREG, mpr	
		pop		mpr		; Restore mpr

		ret						; End a function with RET

;-----------------------------------------------------------
; Func:	SPEED_UP
; Desc:	Increments speed and updates LED's based on 
;		speed.
;-----------------------------------------------------------
SPEED_UP:	

		; If needed, save variables by pushing to the stack
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			

		ldi		waitcnt, WTime	; Wait 10ms to process singular button press
		rcall	Wait

		; Execute the function here
		; Conditional to check max speed
		lds		mpr, OCR1AL		; Check if lower byte of timer register are equal to low 255 (max speed)
		cpi		mpr, 0xFF		
		breq	SKIP_UP			; If not equal increments speed

		ldi		mpr, 0x11		; 17 in hex
		ldi		mpr2, 0x00		; Value to ensure upper byte of timer register stays 0
		add		spd, mpr		; Increments duty cycle by 17
		
		sts		OCR1AH, mpr2		; OCR1A for LED 5
		sts		OCR1AL, spd			; Sends new duty cycle to timer
		sts		OCR1BH, mpr2		; OCR1B for LED 6
		sts		OCR1BL, spd			; Sends new duty cycle to timer
		
		in		mpr, PORTB			; Grabs PORTB input
		andi	mpr, 0xF0			; Saves upper bit LED values (4-7 bits) for engine indicator
		mov		mpr2, spd			; Copy spd value to mpr2
		andi	mpr2, 0x0F			; Save lower bit LED values (0-3 bits) for speed level indicator
		or		mpr, mpr2			; Combines upper and lower bit LED values
		out		PORTB, mpr			; Displays new speed level and engine indicator values

SKIP_UP:

		ldi		mpr, 0b00001011	; Clears any interrupt queues
		out		EIFR, mpr

		; Restore any saved variables by popping from stack
		pop		mpr		; Restore program state
		out		SREG, mpr	
		pop		mpr		; Restore mpr

		ret						; End a function with RET

;-----------------------------------------------------------
; Func:	SPEED_DOWN
; Desc:	Decrements speed and updates LED's based on 
;		speed.
;-----------------------------------------------------------
SPEED_DOWN:	

		; If needed, save variables by pushing to the stack
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;		; Execute the function here

		ldi		waitcnt, WTime
		rcall	Wait

		; Execute the function here
		; Conditional to check min speed
		lds		mpr, OCR1AL			; Check if lower byte of timer register are equal to low 0 (min speed)
		cpi		mpr, 0x00
		breq	SKIP_DOWN			; If not equal decrements speed

		ldi		mpr, 0x11			; 17 in hex
		ldi		mpr2, 0x00			; Value to ensure upper byte of timer register stays 0
		sub		spd, mpr			; Decrements duty cycle by 17
		
		sts		OCR1AH, mpr2		; OCR1A for LED 5
		sts		OCR1AL, spd			; Sends new duty cycle to timer
		sts		OCR1BH, mpr2		; OCR1B for LED 6
		sts		OCR1BL, spd			; Sends new duty cycle to timer
		
		in		mpr, PORTB			; Grabs PORTB input
		andi	mpr, 0xF0			; Saves upper bit LED values (4-7 bits) for engine indicator
		mov		mpr2, spd			; Copy spd value to mpr2
		andi	mpr2, 0x0F			; Save lower bit LED values (0-3 bits) for speed level indicator
		or		mpr, mpr2			; Combines upper and lower bit LED values
		out		PORTB, mpr			; Displays new speed level and engine indicator values

SKIP_DOWN:

		ldi		mpr, 0b00001011	; Clears any interrupt queues
		out		EIFR, mpr

		; Restore any saved variables by popping from stack
		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		mpr		; Restore mpr

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
		; Enter any stored data you might need here

;***********************************************************
;*	Additional Program Includes
;***********************************************************
		; There are no additional file includes for this program
