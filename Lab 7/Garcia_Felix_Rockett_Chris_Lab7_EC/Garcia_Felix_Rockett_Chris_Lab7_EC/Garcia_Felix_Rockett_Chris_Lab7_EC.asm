
;***********************************************************
;*
;*	This is the TRANSMIT skeleton file for Lab 7 of ECE 375
;*
;*  	Rock Paper Scissors
;* 	Requirement:
;* 	1. USART1 communication
;* 	2. Timer/counter1 Normal mode to create a 1.5-sec delay
;***********************************************************
;*
;*	 Author: Christopher Rockett
;*	   Date: 2/25/2026
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register
.def	choice = r17
.def	choice2 = r18
.def	waitcnt = r19			; Wait Loop Counter
.def	mpr2 = r23
.def	i = r24

.equ	WTime = 10		;5ms Wait
.equ	RPSButt = 4
.equ	StartButt = 7
; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111

;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            	; Reset interrupt

.org	$0002					; INT0 interrupt
		rcall	RPS				; Goes through Rock, Paper, Scissors
		reti

.org	$0004					; INT1 interrupt
		rcall	RPS2				; Goes through Rock, Paper, Scissors
		reti

.org    $0056                   ; End of Interrupt Vectors

;***********************************************************
;*  Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND
	
	;I/O Ports
	; Initialize Port D for input
		ldi		mpr, $08		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input and PD3 to output transmitting
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

		; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low

	;USART1
		;Set baudrate at 2400bps
		;Enable receiver and transmitter
		;Set frame format: 8 data bits, 2 stop bits

		; Set baud rate
		ldi	mpr, 0x03		; 832 (0x0340) UBRR high byte
		sts UBRR1H, mpr
		ldi	mpr, 0x40		; 832 (0x0340) UBRR low byte
		sts UBRR1L, mpr
		; Enable receiver and transmitter
		ldi mpr, (1<<RXEN1)|(1<<TXEN1)
		sts UCSR1B, mpr
		; Set frame format: 8data, 2stop bit
		ldi mpr, (1<<USBS1)|(3<<UCSZ10)
		sts UCSR1C, mpr

	;TIMER/COUNTER1
		;Set Normal mode

		ldi	mpr, 0b00000000 ; Sets Timer1 to normal mode
		sts	TCCR1A, mpr

		; Prescaler 256
		; Value = 18661

		ldi mpr, 0b11000100 ; Prescaling 256 clock
		sts TCCR1B, mpr

	;Other
	; Initialize LCD Display
		rcall	LCDInit			; Initializes LCD
		rcall	LCDClr			; Clears dots on LCD

		; Configure External Interrupts, if needed
		ldi		mpr, 0b0000_1010	; Sets intterupts INT0, INT1, and INT3 to falling edge (10) (0-3, and 6-7 bits)
		sts		EICRA, mpr

		ldi		mpr, 0b0000_0011	; Sets INT0
		out		EIMSK, mpr


;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
		rcall	DisplayStart
		ldi		choice, -1
		ldi		choice2, -1
		
		in		mpr, PIND		; Get button input from Port D
		andi	mpr, (0b10000000)	; Sets inputs and outputs for buttons (Active Low)
		cpi		mpr, (0b00000000)	; Check for ButtClr input (Recall Active Low)
		brne	MAIN
		rcall	Play			; Call play function
		rjmp	MAIN			; Continue with program
		


;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;***********************************************************
;*	Stored Program Data
;***********************************************************
WAIT_15sec:
	push	mpr			; Save mpr register
	in		mpr, SREG	; Save program state
	push	mpr			;		; Execute the function here
	push	mpr2
	push	waitcnt
	push	i

	ldi		mpr, low(0x48E5)	; 18661 = 0x48E5 read low first 10ms
	ldi		mpr2, high(0x48E5)  ; 18661 = 0x48E5
	sts		TCNT1H, mpr2
	sts		TCNT1L, mpr 

; Wait for TCNT1 to roll over 
CHECK: 
	in		mpr, TIFR1		; Read in TIFR1  
	andi	mpr, 0b00000001	; Check if TOV1 set  
	breq	CHECK 		; Loop if TOV1 not set 
	ldi		mpr, 0b00000001	; Otherwise, Reset TOV1  
	out		TIFR1, mpr 		; Note - write 1 to reset 

	pop		i
	pop		waitcnt
	pop		mpr2
	pop		mpr			; Save mpr register
	out		SREG, mpr	; Save program state
	pop		mpr			;		; Execute the function here

	ret

;----------------------------------------------------------------
; Sub:	DisplayStart
; Desc:	Sets LCD to display words from program memory
;		
;----------------------------------------------------------------
DisplayStart:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;		; Execute the function here
		push	mpr2

		rcall	LCDBacklightOn				; LCD Backlight on
		rcall	CLRDM1						; Clears both lines with spaces
		rcall	CLRDM2
		ldi		ZL, low(START1_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(START1_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP						; Keeps going though loop till i is 0

		ldi		XL, low($0110)				; Initializes Y pointer address to beginning of second line
		ldi		XH, high($0110)
		ldi		ZL, low(START2_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(START2_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z



		ldi		i, 16						; Sets loop number
LOOP2:
		lpm		mpr, z+						; Sends new x data to mpr register
		st		X+, mpr						; mpr data stored into Y pointer then increases
		dec		i							; Decrements i
		brne	LOOP2						; Keeps going through loop till i is 0
		
		rcall	LCDWrite					; X and Y data onto LCD because of their addresses

		
		; Restore variables by popping them from the stack,
		; in reverse order
		pop		mpr2
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret						; End a function with RET

;----------------------------------------------------------------
; Sub:	DisplayReady
; Desc:	Sets LCD to display words from program memory
;		
;----------------------------------------------------------------
DisplayReady:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;		; Execute the function here

		rcall	LCDBacklightOn				; LCD Backlight on
		rcall	CLRDM1						; Clears both lines with spaces
		rcall	CLRDM2
		ldi		ZL, low(WAIT1_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(WAIT1_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP3:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP3						; Keeps going though loop till i is 0

		ldi		XL, low($0110)				; Initializes Y pointer address to beginning of second line
		ldi		XH, high($0110)
		ldi		ZL, low(WAIT2_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(WAIT2_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z



		ldi		i, 16						; Sets loop number
LOOP4:
		lpm		mpr, z+						; Sends new x data to mpr register
		st		X+, mpr						; mpr data stored into Y pointer then increases
		dec		i							; Decrements i
		brne	LOOP4						; Keeps going through loop till i is 0
		
		rcall	LCDWrite					; X and Y data onto LCD because of their addresses

		
		; Restore variables by popping them from the stack,
		; in reverse order
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret						; End a function with RET

;----------------------------------------------------------------
; Sub:	DisplayGame
; Desc:	Sets LCD to display words from program memory
;		
;----------------------------------------------------------------
DisplayGame:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;		; Execute the function here

		rcall	LCDBacklightOn				; LCD Backlight on
		rcall	CLRDM1						; Clears line with spaces
		rcall	CLRDM2
		ldi		ZL, low(GAME_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(GAME_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP5:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP5						; Keeps going though loop till i is 0
		
		rcall	LCDWrite					; X and Y data onto LCD because of their addresses

		
		; Restore variables by popping them from the stack,
		; in reverse order
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret						; End a function with RET
;----------------------------------------------------------------
; Sub:	USART_Transmit
; Desc:	Waits for empty trasmit buffer
;		
;----------------------------------------------------------------
USART_Transmit:
		; Wait for empty transmit buffer
		lds		mpr2, UCSR1A
		sbrs	mpr2, UDRE1				
		rjmp	USART_Transmit
		ret

USART_Receive:
		; Wait for data to be received
		lds		mpr2, UCSR1A
		sbrs	mpr2, RXC1
		rjmp	USART_Receive
		; Get and return received data from buffer
		lds		mpr, UDR1
		ret

LED_Count:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2
		push	i

		ldi		i, 5
		ldi		mpr2, 0xF0

LOOP7:
		in		mpr, PORTB			; Grabs PORTB input
		andi	mpr, 0x0F			; Save lower bit LED values (0-3 bits) for LCD screen
		or		mpr, mpr2			; Combines upper and lower bit LED values
		out		PORTB, mpr			; Displays count
		rcall	WAIT_15sec			; Shifts LED every 1.5sec
		lsr		mpr2				; Shift Right
		dec		i
		brne	LOOP7

		ldi		mpr2, 0xF0
        out     PORTB, mpr2

		pop		i
		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret
;----------------------------------------------------------------
; Sub:	Play
; Desc:	Waits for other player ready
;		
;----------------------------------------------------------------
Play:
		
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;		; Execute the function here

		rcall	DisplayReady	
		
		; SENDS DATA
		; Wait for empty transmit buffer

		rcall	USART_Transmit
		ldi		mpr, SendReady
		sts		UDR1, mpr
		; Check for Start Button Press
RECEIVE:
		rcall	USART_Receive
		cpi		mpr, SendReady
		breq	BOTH_READY
		rjmp	RECEIVE

BOTH_READY:
		; 4 LEDS counts down in 1.5 second intervals while displaying "GAME START"
		rcall	DisplayGame
	
SELECTS:
		; LED COUNT
		; NEED SELECTION FUNCTION

		ldi		mpr, 0b0000_0011	; Clears any interrupt queues
		out		EIFR, mpr
		sei ; Turns on interrupts
		rcall	LED_Count
		cli	; Turn off interrupts

		rcall	USART_Transmit
		ldi		mpr, SendReady
		sts		UDR1, mpr

SELECT:
		rcall	USART_Receive
		cpi		mpr, SendReady
		breq	BOTH_SELECT
		rjmp	SELECT

BOTH_SELECT:
		rcall	USART_Transmit
		mov		mpr, choice
		sts		UDR1, mpr

		rcall	USART_Receive
		cpi		mpr, 0
		breq	OPP_ROCK
		cpi		mpr, 1
		breq	OPP_PAPER
		rjmp	OPP_SCISSORS

OPP_ROCK:
		rcall	DisplayRockTR
		mov		mpr2, mpr

		rcall	USART_Transmit
		mov		mpr, choice2
		sts		UDR1, mpr

		rcall	USART_Receive
		cpi		mpr, 0
		breq	OPP_ROCK2
		cpi		mpr, 1
		breq	OPP_PAPER2
		rjmp	OPP_SCISSORS2

		rcall	LED_Count
		cp		choice, mpr2
		breq	TIE
		cpi		choice, 1
		breq	WIN
		rjmp	LOSE

OPP_PAPER:
		rcall	DisplayPaperTL
		rcall	LED_Count
		cp		choice, mpr2
		breq	TIE
		cpi		choice, 2
		breq	WIN
		rjmp	LOSE

OPP_PAPER:
		rcall	DisplayPaperTR
		mov		mpr2, mpr
		rcall	LED_Count
		cp		choice, mpr2
		breq	TIE
		cpi		choice, 2
		breq	WIN
		rjmp	LOSE

OPP_SCISSORS:
		rcall	DisplayScissorsTR
		mov		mpr2, mpr
		rcall	LED_Count
		cp		choice, mpr2
		breq	TIE
		cpi		choice, 0
		breq	WIN
		rjmp	LOSE

WIN:
		rcall	DisplayWin
		rjmp	RESET

LOSE:	
		rcall	DisplayLose
		rjmp	RESET

TIE:
		rcall	DisplayTie
		rjmp	RESET

RESET:
		pop		mpr
		out		SREG, mpr
		pop		mpr
		rcall	LED_Count
		ret

DisplayWin:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM1
		ldi		ZL, low(WON_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(WON_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 16						; Sets loop number

LOOPW1:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOPW1						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayLose:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM1
		ldi		ZL, low(LOST_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(LOST_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 16						; Sets loop number

LOOPL:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOPL						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayTie:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM1
		ldi		ZL, low(TIE_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(TIE_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 16						; Sets loop number

LOOPT:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOPT						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayRockLB:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(ROCK_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(ROCK_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0110)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0110)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP8:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP8						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn2					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayRockRB:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(ROCK_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(ROCK_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0118)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0118)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP801:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP801						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn2					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayRockLT:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(ROCK_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(ROCK_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP81:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP81						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayRockRT:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(ROCK_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(ROCK_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0108)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0108)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP8101:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP8101						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayPaperLB:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(PAPER_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(PAPER_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0110)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0110)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP9:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP9						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn2					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayPaperRB:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(PAPER_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(PAPER_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0118)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0118)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP901:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP901						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn2					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayPaperLT:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(PAPER_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(PAPER_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP91:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP91						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayPaperRT:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(PAPER_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(PAPER_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0108)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0108)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP9101:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP9101						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayScissorsLB:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(SCISSORS_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(SCISSORS_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0110)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0110)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP10:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP10						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn2					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayScissorsRB:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(SCISSORS_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(SCISSORS_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0118)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0118)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP1001:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP1001						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn2					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayScissorsLT:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(SCISSORS_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(SCISSORS_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP101:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP101						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

DisplayScissorsRT:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		ldi		ZL, low(SCISSORS_STRING<<1)		; Gets address of lower Beginning String data stores to pointer Z
		ldi		ZH, high(SCISSORS_STRING<<1)		; Gets address of higher Beginning String data stores to pointer Z
		ldi		XL, low($0108)				; Gets address of lower 0100 data stores to pointer Y for first line of LCD
		ldi		XH, high($0108)				; Gets address of higher 0100 data stores to pointer Y for first line of LCD

		ldi		i, 8						; Sets loop number

LOOP101:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into Y pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP101						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

RPS:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2
		push	waitcnt

		inc		choice
		cpi		choice, 3
		brne	SELECTION
		clr		choice

SELECTION:
		cpi		choice, 0
		breq	ROCK
		cpi		choice, 1
		breq	PAPER
		rjmp	SCISSORS

ROCK:
		rcall	DisplayRock
		rjmp	DONE
PAPER:
		rcall	DisplayPaper
		rjmp	DONE
SCISSORS:
		rcall	DisplayScissors
		rjmp	DONE

DONE:
		ldi		mpr, 0b0000_0001	; Clears any interrupt queues
		out		EIFR, mpr

		pop		waitcnt
		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

RPS2:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2
		push	waitcnt

		inc		choice2
		cpi		choice2, 3
		brne	SELECTION2
		clr		choice2

SELECTION2:
		cpi		choice2, 0
		breq	ROCK2
		cpi		choice2, 1
		breq	PAPER2
		rjmp	SCISSORS2

ROCK2:
		rcall	DisplayRockLB
		rjmp	DONE2
PAPER2:
		rcall	DisplayPaperLB
		rjmp	DONE2
SCISSORS2:
		rcall	DisplayScissorsLB
		rjmp	DONE2

DONE2:
		ldi		mpr, 0b0000_0011	; Clears any interrupt queues
		out		EIFR, mpr

		pop		waitcnt
		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
START1_STRING:
    .DB		"Welcome!        "		; Declaring data in ProgMem
START2_STRING:
	.DB		"Please Press PD7"
WAIT1_STRING:
	.DB		"Ready. Waiting  "
WAIT2_STRING:
	.DB		"for the opponent"
GAME_STRING:
	.DB		"Game start      "
ROCK_STRING:
	.DB		"Rock    "
PAPER_STRING:
	.DB		"Paper   "
SCISSORS_STRING:
	.DB		"Scissor "
WON_STRING:
	.DB		"You won!        "
LOST_STRING:
	.DB		"You lost        "
TIE_STRING:
	.DB		"Tie!            "


;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver

