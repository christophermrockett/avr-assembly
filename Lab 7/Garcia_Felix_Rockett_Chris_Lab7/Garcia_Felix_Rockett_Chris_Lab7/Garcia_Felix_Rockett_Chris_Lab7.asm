
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
.def	mpr2 = r17			; Wait Loop Counter
.def	choice = r18
.def	i = r19
.def	waitcnt = r23

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
		ldi		mpr, 0b0000_0010	; Sets intterupts INT0, INT1, and INT3 to falling edge (10) (0-3, and 6-7 bits)
		sts		EICRA, mpr

		ldi		mpr, 0b0000_0001	; Sets INT0
		out		EIMSK, mpr


;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
		rcall	DisplayStart	; Shows Start Screen Initially
		ldi		choice, -1		; Sets choice to -1 to start at Rock in cycle
		
		in		mpr, PIND		; Get button input from Port D
		andi	mpr, (0b10000000)	; Sets inputs and outputs for buttons (Active Low)
		cpi		mpr, (0b00000000)	; Check for ButtClr input (Recall Active Low)
		brne	MAIN			; Loops Main Function
		rcall	Play			; Call play function
		rjmp	MAIN			; Continue with program
		


;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;----------------------------------------------------------------
; Sub:	DisplayWin
; Desc:	Displays "You won!" on first line of LCD
;		
;----------------------------------------------------------------
WAIT_15sec:
	push	mpr			; Save mpr register
	in		mpr, SREG	; Save program state
	push	mpr				
	push	mpr2
	push	waitcnt
	push	i

	ldi		mpr, low(0x48E5)	; 18661 = 0x48E5 read low first 1.5 secs
	ldi		mpr2, high(0x48E5)  ; 18661 = 0x48E5
	sts		TCNT1H, mpr2		; Write high first
	sts		TCNT1L, mpr			; Write high first

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
	pop		mpr			

	ret

;----------------------------------------------------------------
; Sub:	DisplayStart
; Desc:	Sets LCD to display words from program memory
;		
;----------------------------------------------------------------
DisplayStart:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			
		push	mpr2

		rcall	LCDBacklightOn				; LCD Backlight on
		rcall	CLRDM1						; Clears both lines with spaces
		rcall	CLRDM2
		ldi		ZL, low(START1_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(START1_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer X for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP1:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP1						; Keeps going though loop till i is 0

		ldi		XL, low($0110)				; Initializes X pointer address to beginning of second line
		ldi		XH, high($0110)
		ldi		ZL, low(START2_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(START2_STRING<<1)		; Gets address of higher string and stores to pointer Z



		ldi		i, 16						; Sets loop number
LOOP2:
		lpm		mpr, z+						; Sends new z data to mpr register
		st		X+, mpr						; mpr data stored into X pointer then increases
		dec		i							; Decrements i
		brne	LOOP2						; Keeps going through loop till i is 0
		
		rcall	LCDWrite					; Writes data onto LCD because of their addresses

		
		; Restore variables by popping them from the stack,
		; in reverse order
		pop		mpr2
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret						

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
		ldi		ZL, low(WAIT1_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(WAIT1_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer X for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP3:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP3						; Keeps going though loop till i is 0

		ldi		XL, low($0110)				; Initializes Y pointer address to beginning of second line
		ldi		XH, high($0110)
		ldi		ZL, low(WAIT2_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(WAIT2_STRING<<1)		; Gets address of higher string and stores to pointer Z



		ldi		i, 16						; Sets loop number
LOOP4:
		lpm		mpr, z+						; Sends new z data to mpr register
		st		X+, mpr						; mpr data stored into X pointer then increases
		dec		i							; Decrements i
		brne	LOOP4						; Keeps going through loop till i is 0
		
		rcall	LCDWrite					; Writes data onto LCD because of their addresses

		
		; Restore variables by popping them from the stack,
		; in reverse order
		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret						

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
		ldi		ZL, low(GAME_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(GAME_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer X for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP5:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP5						; Keeps going though loop till i is 0
		
		rcall	LCDWrite					; Writes data onto LCD because of their addresses

		pop		mpr							; Pops old mpr value
		out		SREG, mpr					; Restores old SREG value
		pop		mpr							; Pops old mpr value

		ret						
;----------------------------------------------------------------
; Sub:	USART_Transmit
; Desc:	Waits for empty trasmit buffer
;		
;----------------------------------------------------------------
USART_Transmit:
		lds		mpr2, UCSR1A	; Wait for empty transmit buffer
		sbrs	mpr2, UDRE1				
		rjmp	USART_Transmit
		ret

;----------------------------------------------------------------
; Sub:	USART_Receive
; Desc:	Waits for data to be received
;		
;----------------------------------------------------------------
USART_Receive:
		lds		mpr2, UCSR1A	; Wait for data to be received
		sbrs	mpr2, RXC1
		rjmp	USART_Receive
		
		lds		mpr, UDR1		; Get and return received data from buffer
		ret

;----------------------------------------------------------------
; Sub:	LED_Count
; Desc:	Counts for 6 seconds utilizing LEDS (4-7)
;		
;----------------------------------------------------------------
LED_Count:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2
		push	i

		ldi		i, 5
		ldi		mpr2, 0xF0			; Light all 4 LEDS Initially

LOOP6:
		in		mpr, PORTB			; Grabs PORTB input
		andi	mpr, 0x0F			; Save lower bit LED values (0-3 bits) for LCD screen
		or		mpr, mpr2			; Combines upper and lower bit LED values
		out		PORTB, mpr			; Displays count
		rcall	WAIT_15sec			; Shifts LED every 1.5sec
		lsr		mpr2				; Shift Right
		dec		i
		brne	LOOP6

		pop		i
		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	Play
; Desc:	Waits for other player ready and plays game
;		
;----------------------------------------------------------------
Play:
		
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			

		rcall	DisplayReady	; Displays ready screen
		
		rcall	USART_Transmit	; Transmit Ready Signal
		ldi		mpr, SendReady
		sts		UDR1, mpr
		
RECEIVE:
		rcall	USART_Receive	; Check if both boards are ready
		cpi		mpr, SendReady	; Checks if both boards send same ready signal
		breq	BOTH_READY		; Branches if both boards are ready
		rjmp	RECEIVE			; Keeps Checking for Signal

BOTH_READY:
		rcall	DisplayGame		; Displays Game screen
	
SELECTS:
		ldi		mpr, 0b0000_0001	; Clears any interrupt queues
		out		EIFR, mpr
		sei							; Turns on interrupts
		rcall	LED_Count			; Counts for 6 seconds
		cli							; Turn off interrupts

		rcall	USART_Transmit		; Handshakes with other board to check if synced
		ldi		mpr, SendReady
		sts		UDR1, mpr

SELECT:
		rcall	USART_Receive
		cpi		mpr, SendReady
		breq	BOTH_SELECT
		rjmp	SELECT

BOTH_SELECT:
		rcall	USART_Transmit		; When boards are synced, send RPS choice
		mov		mpr, choice
		sts		UDR1, mpr

		rcall	USART_Receive		; Receive other boards choice 
		cpi		mpr, 0				; Opponent's choice is Rock
		breq	OPP_ROCK
		cpi		mpr, 1				; Opponent's choice is Paper
		breq	OPP_PAPER			
		rjmp	OPP_SCISSORS		; Opponent's choice is Scissors

OPP_ROCK:
		rcall	DisplayRock1		; Displays Rock as opponent's choice
		rcall	LED_Count			; Counts for 6 seconds
		cp		choice, mpr			; Compares both inputs to determine tie
		breq	TIE					
		cpi		choice, 1			; Checks if user's input beats rock (Paper)
		breq	WIN
		rjmp	LOSE

OPP_PAPER:
		rcall	DisplayPaper1		; Displays Paper as opponent's choice
		rcall	LED_Count			; Counts for 6 seconds
		cp		choice, mpr			; Compares both inputs to determine tie
		breq	TIE
		cpi		choice, 2			; Checks if user's input beats paper (Scissors)
		breq	WIN
		rjmp	LOSE

OPP_SCISSORS:
		rcall	DisplayScissors1	; Displays Scissors as opponent's choice
		rcall	LED_Count			; Counts for 6 seconds
		cp		choice, mpr			; Compares both inputs to determine tie
		breq	TIE
		cpi		choice, 0			; Checks if user's input beats Scissors (Rock)
		breq	WIN
		rjmp	LOSE

WIN:
		rcall	DisplayWin			; Display Win screen
		rjmp	RESET

LOSE:	
		rcall	DisplayLose			; Display Lose screen
		rjmp	RESET

TIE:
		rcall	DisplayTie			; Display Tie screen
		rjmp	RESET

RESET:
		pop		mpr					; Goes back to Main function
		out		SREG, mpr
		pop		mpr
		rcall	LED_Count			; Counts for 6 seconds
		ret

;----------------------------------------------------------------
; Sub:	DisplayWin
; Desc:	Displays "You won!" on first line of LCD
;		
;----------------------------------------------------------------
DisplayWin:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM1
		ldi		ZL, low(WON_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(WON_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer X for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP7:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP7						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 1 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	DisplayLose
; Desc:	Displays "You lost" on first line of LCD
;		
;----------------------------------------------------------------
DisplayLose:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM1
		ldi		ZL, low(LOST_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(LOST_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer X for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP8:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP8						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 1 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	DisplayTie
; Desc:	Displays "Tie!" on first line of LCD
;		
;----------------------------------------------------------------
DisplayTie:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM1
		ldi		ZL, low(TIE_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(TIE_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer X for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP9:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP9						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 1 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	DisplayRock
; Desc:	Displays "Rock" on second line of LCD
;		
;----------------------------------------------------------------
DisplayRock:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM2
		ldi		ZL, low(ROCK_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(ROCK_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0110)				; Gets address of lower 0110 data stores to pointer X for first line of LCD
		ldi		XH, high($0110)				; Gets address of higher 0110 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP10:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP10						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn2					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	DisplayRock1
; Desc:	Displays "Rock" on first line of LCD
;		
;----------------------------------------------------------------
DisplayRock1:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM1
		ldi		ZL, low(ROCK_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(ROCK_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer X for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP11:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP11						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 1 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	DisplayPaper
; Desc:	Displays "Paper" on second line of LCD
;		
;----------------------------------------------------------------
DisplayPaper:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM2
		ldi		ZL, low(PAPER_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(PAPER_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0110)				; Gets address of lower 0110 data stores to pointer X for first line of LCD
		ldi		XH, high($0110)				; Gets address of higher 0110 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP12:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP12						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn2					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	DisplayPaper1
; Desc:	Displays "Paper" on first line of LCD
;		
;----------------------------------------------------------------
DisplayPaper1:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM1
		ldi		ZL, low(PAPER_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(PAPER_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer X for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP13:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP13						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 1 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	DisplayScissors
; Desc:	Displays "Scissors" on second line of LCD
;		
;----------------------------------------------------------------
DisplayScissors:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM2
		ldi		ZL, low(SCISSORS_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(SCISSORS_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0110)				; Gets address of lower 0110 data stores to pointer X for first line of LCD
		ldi		XH, high($0110)				; Gets address of higher 0110 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP14:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP14						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn2					; Data onto LCD line 2 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	DisplayScissors1
; Desc:	Displays "Scissors" on first line of LCD
;		
;----------------------------------------------------------------
DisplayScissors1:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2

		rcall	CLRDM1
		ldi		ZL, low(SCISSORS_STRING<<1)		; Gets address of lower string and stores to pointer Z
		ldi		ZH, high(SCISSORS_STRING<<1)		; Gets address of higher string and stores to pointer Z
		ldi		XL, low($0100)				; Gets address of lower 0100 data stores to pointer X for first line of LCD
		ldi		XH, high($0100)				; Gets address of higher 0100 data stores to pointer X for first line of LCD

		ldi		i, 16						; Sets loop number

LOOP15:
		lpm		mpr, z+						; Sends Z data into mpr register
		st		X+, mpr						; Sends mpr data into X pointer then increases address by 1
		dec		i							; Decrements i
		brne	LOOP15						; Keeps going though loop till i is 0
		
		rcall	LCDWrLn1					; Data onto LCD line 1 because of address

		pop		mpr2
		pop		mpr
		out		SREG, mpr
		pop		mpr

		ret

;----------------------------------------------------------------
; Sub:	RPS
; Desc:	Cycles and displays rock, paper, scissors choice
;		
;----------------------------------------------------------------
RPS:
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr		
		push	mpr2
		push	waitcnt

		inc		choice			; Increments choice variable
		cpi		choice, 3		; Resets choice to Rock if incremented past Scissors (2)
		brne	SELECTION
		clr		choice

SELECTION:
		cpi		choice, 0		; 0 = Rock
		breq	ROCK
		cpi		choice, 1		; 1 = Paper
		breq	PAPER
		rjmp	SCISSORS		; 2 = Scissors

ROCK:
		rcall	DisplayRock		; Displays Rock screen
		rjmp	DONE
PAPER:
		rcall	DisplayPaper	; Displays Paper sreen
		rjmp	DONE
SCISSORS:
		rcall	DisplayScissors	; Displays Scissors screen
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
	.DB		"Rock            "
PAPER_STRING:
	.DB		"Paper           "
SCISSORS_STRING:
	.DB		"Scissors        "
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

