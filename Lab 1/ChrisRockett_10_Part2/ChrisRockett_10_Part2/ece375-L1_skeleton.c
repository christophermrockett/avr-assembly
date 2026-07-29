
/*

Christopher Rockett 1/9/2026
This code will cause a TekBot connected to the AVR board to
move forward and when it touches an obstacle, it will reverse
and turn away from the obstacle and resume forward motion.

PORT MAP
Port B, Pin 5 -> Output -> Right Motor Enable
Port B, Pin 4 -> Output -> Right Motor Direction
Port B, Pin 6 -> Output -> Left Motor Enable
Port B, Pin 7 -> Output -> Left Motor Direction
Port D, Pin 5 -> Input -> Left Whisker
Port D, Pin 4 -> Input -> Right Whisker
*/

#define F_CPU 16000000
#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>

int main(void)
{
	DDRB = 0b11110000;      // configure Port B pins for input/output
	DDRD = 0b11001111;		// configure Port D (active low)
	PORTD = 0b00110000;		// set initial Port D Values
	PORTB = 0b11110000;     // set initial value for Port B outputs (Everything ON = not moving)
	
	while (1) // loop forever
	{
		PORTB = 0b10010000;     // make TekBot move forward
		uint8_t mpr = PIND & 0b00110000; // reading only 4-5th bit

		
		if (mpr == 0b00100000 || mpr == 0b00000000) { // checks if right bumper  or both are hit is hit (Active low button)
			PORTB = 0b00000000; // reverse
			_delay_ms(2000); // 2 second
			PORTB = 0b00010000; // turn left
			_delay_ms(1000); // 1 second
			continue;
		}
		
		else if (mpr == 0b00010000) { // checks if left bumper is hit
			PORTB = 0b00000000; // reverse
			_delay_ms(2000); // 1 second
			PORTB = 0b10000000; // turn right
			_delay_ms(1000); // 1 second
			continue;
		}
		
	}
}
