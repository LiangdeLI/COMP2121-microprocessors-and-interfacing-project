/*
 * modules.asm
 *
 *  Created: 29/10/2017 3:21:23 PM
 *   Author: Lee
 */ 

 .include "m2560def.inc"

 .cseg
	.org 0x0000
		jmp RESET

 RESET:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

 // Interrupt 0 module
// start here
/*EXT_INT0:
	push temp
	push temp1
	in temp, SREG
	push temp
	push r21
	push r23
	push r10
	push r9
	push r8
		cpi flag, 1
		brne real_int0
		clr flag
		pop r8
		pop r9
		pop r10
		pop r23
	    pop r21
		pop temp
		out SREG, temp
		pop temp
		reti
	real_int0:
		ldi flag, 1
		lds temp, TargetSpeed
		cpi temp, 100
		breq END_BUTTON_ZERO
		ldi temp1, 20
		add temp, temp1
	END_BUTTON_ZERO:
		sts TargetSpeed, temp
		do_lcd_command 0b00001000 ; display off
		do_lcd_command 0b00000001 ; clear display
	    do_lcd_command 0b00000110 ; increment, no display shift
	    do_lcd_command 0b00001110 ; Cursor on, bar, no blink
		do_lcd_data '0'
		do_lcd_data '0'
		ldi r23, 1
		clr r21
		ldi temp, 0xDB
		mov r8, temp  
		ldi temp, 0x7C
		mov r9, temp
		ldi temp, 0x03
		mov r10, temp
		delay1:
		sub r8, r23
		sbc r9, r21
		sbc r10, r21
		cp r8, r21
		cpc r9, r21
		cpc r10, r21
		brne delay1
	pop r8
	pop r9
	pop r10
	pop r23
	pop r21
	pop temp
	out SREG, temp
	pop temp1
	pop temp
	reti*/
// end here
// Interrupt 0 module





// Interrupt 1 module
// start here
/*EXT_INT1:
	push temp
	push temp1
	in temp, SREG
	push temp
	push r21
	push r23
	push r10
	push r9
	push r8
		cpi flag, 1
		brne real_int1
		clr flag
	    pop r8
	    pop r9
	    pop r10
		pop r23
	    pop r21
		pop temp
		out SREG, temp
		pop temp
		reti
	real_int1:
		ldi flag, 1
		lds temp, TargetSpeed
		cpi temp, 0
		breq END_BUTTON_ONE
		ldi temp1, 20
		sub temp, temp1
	END_BUTTON_ONE:
		sts TargetSpeed, temp
		do_lcd_command 0b00001000 ; display off
		do_lcd_command 0b00000001 ; clear display
	    do_lcd_command 0b00000110 ; increment, no display shift
	    do_lcd_command 0b00001110 ; Cursor on, bar, no blink
		do_lcd_data '1'
		do_lcd_data '1'
		ldi r23, 1
		clr r21
		ldi temp, 0xDB
		mov r8, temp  
		ldi temp, 0x7C
		mov r9, temp
		ldi temp, 0x03
		mov r10, temp
		delay2:
		sub r8, r23
		sbc r9, r21
		sbc r10, r21
		cp r8, r21
		cpc r9, r21
		cpc r10, r21
		brne delay2
	pop r8
	pop r9
	pop r10
	pop r23
	pop r21
	pop temp
	out SREG, temp
	pop temp1
	pop temp
	reti*/
// end here
// Interrupt 1 module





// Interrupt 2 module
// start here
/*EXT_INT2:
	push temp
	in temp, SREG
	push temp
	push r23
	push r22
		inc holes
		cpi holes, 4
		brne end
		clr holes
		lds r22, RevCounter
		lds r23, RevCounter+1
		ldi temp, 1
		add r22, temp
		ldi temp, 0
		adc r23, temp
		sts RevCounter, r22
		sts RevCounter+1, r23
	end:
		pop r22
		pop r23
		pop temp
		out SREG, temp
		pop temp
		reti*/
// end here
// Interrupt 2 module





// Timer0 module
// start here
/*Timer0OVF: ; interrupt subroutine to Timer0
	in temp, SREG
	push temp ; prologue starts
	push YH ; save all conflicting registers in the prologue
	push YL
	push r25
	push r24
	push r23
	push r22
	push r21
	push r10 
	push r9
	push r8; prologue ends
		; Load the value of the temporary counter
		lds r24, TempCounter
		lds r25, TempCounter+1
		adiw r25:r24, 1 ; increase the temporary counter by one
		cpi r24, low(781) ; check if (r25:r24) = 7812
		ldi temp, high(781) ; 7812 = 10^6/128
		cpc r25, temp
		brne NotASecond
		rjmp one_tenth_second
	NotASecond:
		jmp NotSecond
	one_tenth_second:
		jmp calculation
	end_calculation:
		lds r22, RevCounter
		lds r23, RevCounter+1
		ldi temp, 10
		; r22*10->r25:r24
		mul r22, temp
		mov r24, r0
		mov r25, r1
		; r23*10->r1:r0
		mul r23, temp
		; r25:r24->r24:r23
		mov r23, r24
		mov r24, r25
		ldi temp, 0
		clr r25
		; 0:r24:r23 + r1:r0:0->r25:r24:r23
		add r23, temp
		adc r24, r0
		adc r25, r1
		lds r21, TargetSpeed
		ldi r22, 0
		cp r23, r21
		cpc r24, r22
		brlo less
		; more
		lds r22, OCR3BL
		lds r23, OCR3BH
		ldi temp, 1
		ldi temp1, 0
		sub r22, temp
		sbc r23, temp1
		sts OCR3BL, r22
		sts OCR3BH, r23
	less:
		lds r22, OCR3BL
		lds r23, OCR3BH
		ldi temp, 1
		ldi temp1, 0
		add r22, temp
		adc r23, temp1
		sts OCR3BL, r22
		sts OCR3BH, r23
		ldi r22, 0
		ldi r23, 0
		sts RevCounter, r22
		sts RevCounter+1, r23
		clear_2 TempCounter ; reset the temporary counter
		; Load the value of the second counter
		lds r24, SecondCounter
		lds r25, SecondCounter+1
		adiw r25:r24, 1 ; increase the second counter by one
		sts SecondCounter, r24
		sts SecondCounter+1, r25
		rjmp EndIF
 
	NotSecond: ; store the new value of the temporary counter
		sts TempCounter, r24
		sts TempCounter+1, r25
 
	EndIF: 
		pop r8 ; epilogue starts
		pop r9 ; restore all conflicting registers from the stack
		pop r10;
		pop r21
		pop r22
		pop r23
		pop r24 
		pop r25 
		pop YL
		pop YH
		pop temp
		out SREG, temp
		reti ; return from the interrupt*/
// end here
// Timer0 module





//calculation:
	/*do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?*/
	/*do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	do_lcd_data 'S'
	do_lcd_data 'p'
	do_lcd_data 'e'
	do_lcd_data 'e'
	do_lcd_data 'd'
	do_lcd_data ':'
	
	
	ldi temp, low(10000)
	mov r3, temp
	ldi temp, high(10000)
	mov r4, temp
	ldi temp, low(1000)
	mov r5, temp
	ldi temp, high(1000)
	mov r6, temp
	ldi temp, 100
	mov r9, temp
	ldi temp, 10
	mov r10, temp
	clr d_5
	clr d_4
	clr d_3
	clr d_2
	clr d_1


	ldi r25, 0
	lds temp, RevCounter
	mov result_low, temp
	lds temp, RevCounter+1
	mov result_high, temp
	clr temp

	sub_ten_thousand:
		sub result_low, r3
		sbc result_high, r4
		inc d_5
		cp result_low, r25
		cpc result_high, r25
		brge sub_ten_thousand
		add result_low, r3
		adc result_high, r4
		dec d_5

	sub_thousand:
		sub result_low, r5
		sbc result_high, r6
		inc d_4
		cp result_low, r25
		cpc result_high, r25
		brge sub_thousand
		add result_low, r5
		adc result_high, r6
		dec d_4

	sub_hundred:
		sub result_low, r9
		sbc result_high, r25
		inc d_3
		cp result_low, r25
		cpc result_high, r25
		brge sub_hundred
		add result_low, r9
		adc result_high, r25
		dec d_3

	sub_ten:
		sub result_low, r10
		sbc result_high, r25
		inc d_2
		cp result_low, r25
		cpc result_high, r25
		brge sub_ten
		add result_low, r10
		adc result_high, r25
		dec d_2

	mov d_1, result_low

	mov r16, d_5
	ldi r27, 48
	add r16, r27
	display
	mov r16, d_4
	add r16, r27
	display
	ldi r27, 48
	mov r16, d_3
	add r16, r27
	display
	ldi r27, 48
	mov r16, d_2
	add r16, r27
	display
	ldi r27, 48
	mov r16, d_1
	add r16, r27
	display
	do_lcd_data '0'*/
	//jmp end_calculation