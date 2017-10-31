/*
 * main.asm
 *
 *  Created: 20/10/2017 10:11:17 AM
 *   Author: Liangde Li z5077896 Dankoon Yoo z5116090
 *  LED0-7 -> PC0-7, LED8-9 -> PB0-1, C0-3 -> PL3-0, R0-3 ->PL7-4
 *  OpE -> +5v, PE2 -> JP91, Mot -> Pot, PB0-1 -> RDX4-3,
 *  BE-RS -> PA4-7, D0-7 -> PF0-7
 */ 
 
.include "m2560def.inc"

.def temp = r16
.def temp1 = r17
.def row =r18
.def col =r19
.def mask =r20
.def temp2 = r21
.def leds = r22
.def station = r23
.def flag = r25
.def counter = r15
.def halt = r14
.def blink = r13
.def halt_counter = r12
.def stop_counter = r11
.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

; display the value in r16 on LCD
.macro display
	rcall lcd_data
	rcall lcd_wait
.endmacro

; The macro clears a word (2 bytes) in a memory
; the parameter @0 is the memory address for that word
.macro clear_2
    ldi YL, low(@0)     ; load the memory address to Y
    ldi YH, high(@0)
    clr temp 
    st Y+, temp         ; clear the two bytes at @0 in SRAM
    st Y, temp
.endmacro


                        
.dseg
.org 0x200
	SecondCounter: .byte 2 ; Two-byte counter for counting seconds.
	TempCounter: .byte 2 ; Temporary counter. Used to determine if one second has passed
	MaxStations: .byte 1
	StationNames: .byte 100 
	TimeToNext: .byte 10 
	StopTime: .byte 1
	 

.cseg
	.org 0x0000
		jmp RESET
	.org INT0addr ; INT0addr is the address of EXT_INT0
		jmp EXT_INT0
	.org INT1addr ; INT1addr is the address of EXT_INT1
		jmp EXT_INT1
	jmp DEFAULT          ; default service for all other interrupts.
	DEFAULT:  reti       ; no service

//*************************************************************************************************************
// boarder for modules
//*************************************************************************************************************



// RESET module
// start here
RESET:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	
	ser r16
	// Mot
	out DDRE, r16
	// LCD
	out DDRF, r16
	out DDRA, r16
	clr temp
	out PORTF, r16
	out PORTA, r16
	clr temp
	out DDRD, temp
	out PORTD, temp
	// Interrupts
	ldi temp, (2 << ISC10) | (2 << ISC00)
	sts EICRA, temp
	in temp, EIMSK
	ori temp, (1<<INT0) | (1<<INT1)
	out EIMSK, temp
	// keypad
	ldi temp, PORTLDIR ; columns are outputs, rows are inputs
    STS DDRL, temp     ; cannot use out
    // LEDs
	ser temp
    out DDRC, temp ; Make PORTC all outputs
    out PORTC, temp ; Turn on LEDs 0-7
	out DDRB, temp
	clr temp
	out PORTB, temp ; turn off LED 8-9
	mov blink, temp
	// PWM
	ldi temp1, 0 					
	sts OCR3BH, temp1
	ldi temp1, 0
	sts OCR3BL, temp1
	ldi temp1, 0
	sts TargetSpeed, temp1

	ldi temp1, (1 << CS30) 		; set the Timer3 to Phase Correct PWM mode. 
	sts TCCR3B, temp1
	ldi temp1, (1<< WGM30)|(1<<COM3B1)
	sts TCCR3A, temp1

	clr halt
	// Initilise the LCD display
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	// Display "Max stations:"
	do_lcd_data 'M'
	do_lcd_data 'a'
	do_lcd_data 'x'
	do_lcd_data ' '
	do_lcd_data 's'
	do_lcd_data 't'
	do_lcd_data 'a'
	do_lcd_data 't'
	do_lcd_data 'i'
	do_lcd_data 'o'
	do_lcd_data 'n'
	do_lcd_data 's'
	do_lcd_data ':'	

	// enable globel interrupt
	sei
	jmp main
// end here
// RESET module



//*************************************************************************************************************
// boarder for modules
//*************************************************************************************************************



 // Interrupt 0 module
// start here
EXT_INT0:
	push temp
	push temp1
	in temp, SREG
	push temp
	ldi temp, 0b11110000 ; turn on LED0-3 later
	or leds, temp
	pop temp
	out SREG, temp
	pop temp1
	pop temp
	reti
// end here
// Interrupt 0 module



//*************************************************************************************************************
// boarder for modules
//*************************************************************************************************************



 // Interrupt 1 module
// start here
EXT_INT1:
	push temp
	push temp1
	in temp, SREG
	push temp
	ldi temp, 0b00001111 ; turn on LED 4-7 later
	or leds, temp
	pop temp
	out SREG, temp
	pop temp1
	pop temp
	reti
// end here
// Interrupt 1 module



//*************************************************************************************************************
// boarder for modules
//*************************************************************************************************************



// main function
// start here
main: ; main - does nothing 
	// Initialise everything in data "StationNames" to be space(32)
	ldi temp, 32
	ldi temp1, 0
	ldi zl, low(StationNames)
	ldi zh, high(StationNames)
	clear_name:
	    cpi temp1, 100
	    breq go_on_7
		//ldi temp, 48
		st z+, temp
		inc temp1
		rjmp clear_name
	go_on_7:
	
	clr temp2
	get_max_num_station:
	    // sleep 200ms for debounce
		call sleep_100ms
		call sleep_100ms
		// get one input from Keypad
		call GetKeypadNumInput 
		// if it is D, check if it's valid value
		cpi temp, 13 
		breq end_check1
		// if it is same or higher than A
		cpi temp, 10 
		brsh error1
	    // if it is a number, display
		ldi temp1, 48 
		add temp, temp1
		display
		sub temp, temp1
		// multiply last gotten value by ten, and add current one
		ldi temp1, 10 
		mul temp2, temp1
		mov temp2, r0
		add temp2, temp
		// get next digit of number
		rjmp get_max_num_station
		// check if value is between 2 and 10 
		end_check1:
		    cpi temp2, 2
			brlo error1
			cpi temp2, 11
			brsh error1
			// if passed, store in MaxStations
		    sts MaxStations, temp2
			rjmp end_get_max_num_station
		// any error happend in the process above, display below
		error1:
			do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_5ms
			do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_1ms
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00001000 ; display off?
		    do_lcd_command 0b00000001 ; clear display
			do_lcd_command 0b00000110 ; increment, no display shift
			do_lcd_command 0b00001110 ; Cursor on, bar, no blink
			do_lcd_data 'X'
			do_lcd_data 'M'
			do_lcd_data 'a'
			do_lcd_data 'x'
			do_lcd_data ' '
			do_lcd_data 's'
			do_lcd_data 't'
			do_lcd_data 'a'
			do_lcd_data 't'
			do_lcd_data 'i'
			do_lcd_data 'o'
			do_lcd_data 'n'
			do_lcd_data 's'
			do_lcd_data ':'
			clr temp2
			// get number again
			rjmp get_max_num_station
	end_get_max_num_station:

	// boarder for steps
	// already got correct number of stations, stored in MaxStations and (temp2)
	// Then to get the name for each station
	   
        // make z point to StationNames    
	    ldi zl, low(StationNames)
		ldi zh, high(StationNames)
		// start frome station 1
	    ldi r22, 1 ; use r22 as current number of station
		inc temp2
		// clear LCD screen
	    do_lcd_command 0b00111000 ; 2x5x7
	    rcall sleep_5ms
		do_lcd_command 0b00111000 ; 2x5x7
		rcall sleep_1ms
		do_lcd_command 0b00111000 ; 2x5x7
		do_lcd_command 0b00111000 ; 2x5x7
	    do_lcd_command 0b00001000 ; display off?
		do_lcd_command 0b00000001 ; clear display
		do_lcd_command 0b00000110 ; increment, no display shift
		do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	get_names:
	    call sleep_5ms
		// display "Name"	
		do_lcd_data 'N'
		do_lcd_data 'a'
		do_lcd_data 'm'
		do_lcd_data 'e'
		// if currently getting tenth station's
		cpi r22, 10
		breq ten_case
		// display current station number
		ldi temp, 48
		add temp, r22
		display 
		rjmp to_colum
		// display "10"
		ten_case:
		    do_lcd_data '1'
			do_lcd_data '0'
		// display ":"
		to_colum:
		do_lcd_data ':'
		ldi r24, 1
	get_letters:	
		rcall sleep_100ms
		rcall sleep_100ms
		// get keypad input
		call GetKeypadNumInput
		mov r23, temp
		// 1 represent nothing
		cpi r23, 1
		breq error2
		// 0 means space
		cpi r23, 0
		breq space
		// D means confirm, end of one name
		cpi r23, 13
		breq finish_letters
		rjmp go_on1
		finish_letters: jmp end_letters
		go_on1:
		// A, B, C, *, #, not recognized
		cpi r23, 10
		brsh error2
		rjmp go_on2
		space:
		    ldi temp1, 32
			rjmp end_check2
		go_on2:
		rcall sleep_100ms
		rcall sleep_100ms
		// get confirm input for this letter input
		call GetKeypadNumInput
		// should not be 0-9
		cpi temp, 10
		brlo error2
		// should not be D, *, #
		cpi temp, 13
		brsh error2
		// letters on 7, 8, 9 is special
		cpi r23, 7
		breq seven
		cpi r23, 8
		breq eight
		cpi r23, 9
		breq nine
		// number*3+49+confirm, like A is 2*3+49+10
		ldi temp1, 3
		mul temp1, r23
		mov temp1, r0
		ldi r23, 49
		add temp1, r23
		add temp1, temp
		rjmp end_check2
		// if got any error input above, display one more 'X'
		error2:
		    do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_5ms
			do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_1ms
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00001000 ; display off?
		    do_lcd_command 0b00000001 ; clear display
			do_lcd_command 0b00000110 ; increment, no display shift
			do_lcd_command 0b00001110 ; Cursor on, bar, no blink
			rcall sleep_5ms
			do_lcd_data 'X'
			ldi temp, 10
			mul r22, temp
			mov temp, r0
			mov temp1, r1
			// load z of the right address
			ldi zl, low(StationNames)
		    ldi zh, high(StationNames)
			add zl, temp
			adc zh, temp1
			rjmp get_names
		// if '7' is pressed
		seven:
		    cpi temp, 12
			breq letter_s
			cpi temp, 11
			breq letter_r
			ldi temp1, 80
			rjmp end_check2
			letter_s: ldi temp1, 83
			rjmp end_check2
			letter_r: ldi temp1, 82
			rjmp end_check2
		// if '8' is pressed
		eight:
		    ldi temp1, 74
			add temp1, temp
			rjmp end_check2
		// if '9' is pressed
		nine:
		    ldi temp1, 77
			add temp1, temp
			;rjmp end_check2
		// store letter input at right place and display
		end_check2:
		    st z+, temp1
			mov temp, temp1
			display
			// go to get next letter
			inc r24	
			// if already got ten letters    
			cpi r24, 11
		    breq end_letters
			jmp get_letters
		end_letters:
		    // make z point to the start of next name
			ldi temp, 10
			mul r22, temp
			mov temp, r0
			mov temp1, r1
			ldi zl, low(StationNames)
		    ldi zh, high(StationNames)
			add zl, temp
			adc zh, temp1
			inc r22
			// if it's the last name, go to end
	        cp r22, temp2
		    breq end_names
			do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_5ms
			do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_1ms
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00001000 ; display off?
			do_lcd_command 0b00000001 ; clear display
			do_lcd_command 0b00000110 ; increment, no display shift
			do_lcd_command 0b00001110 ; Cursor on, bar, no blink
			jmp get_names
	end_names:

	// boarder for steps
	// already got correct name of each station, stored in StationNames
	// get the value of time to travel between stations
	//
	    
		ldi zl, low(TimeToNext)
	    ldi zh, high(TimeToNext)
		ldi r22, 1 ; use r22 as current number of station
		lds temp2, MaxStations
	get_times:
	    clr r23
	    do_lcd_command 0b00111000 ; 2x5x7
	    rcall sleep_5ms
		do_lcd_command 0b00111000 ; 2x5x7
		rcall sleep_1ms
		do_lcd_command 0b00111000 ; 2x5x7
		do_lcd_command 0b00111000 ; 2x5x7
	    do_lcd_command 0b00001000 ; display off?
		do_lcd_command 0b00000001 ; clear display
		do_lcd_command 0b00000110 ; increment, no display shift
		do_lcd_command 0b00001110 ; Cursor on, bar, no blink
		do_lcd_data 'T'
		do_lcd_data 'i'
		do_lcd_data 'm'
		do_lcd_data 'e'
		mov temp, r22
		call display_station_number 
		do_lcd_data 't'
		do_lcd_data 'o'
		// check if is time from the last to first
		cp r22, temp2
		breq step_end2
		mov temp, r22
		inc temp
		call display_station_number
		rjmp go_on3
		// display last to station 1
		step_end2:
		    do_lcd_data '1'
		go_on3:
		do_lcd_data ':'
	get_numbers:	
		call sleep_100ms
		call sleep_100ms
		call GetKeypadNumInput
		// D for confirme
		cpi temp, 13
		breq end_check3
		// A, B, C, *, # are not valid
		cpi temp, 10
		brsh error3
		// display the value
		ldi temp1, 48
		add temp, temp1
		display
		sub temp, temp1
		ldi temp1, 10
		mul r23, temp1
		mov r23, r0
		add r23, temp
		// go to get next digit
		rjmp get_numbers
		end_check3:
		    // only value between 2 and 10 is valid
		    cpi r23, 1
			brlo error3
			cpi r23, 11
			brsh error3
		    st z+, r23
			rjmp end_get_numbers
		error3:
			do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_5ms
			do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_1ms
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00001000 ; display off?
		    do_lcd_command 0b00000001 ; clear display
			do_lcd_command 0b00000110 ; increment, no display shift
			do_lcd_command 0b00001110 ; Cursor on, bar, no blink
			do_lcd_data 'X'
			do_lcd_data 'T'
		    do_lcd_data 'i'
		    do_lcd_data 'm'
		    do_lcd_data 'e'
		    mov temp, r22
		    call display_station_number 
		    do_lcd_data 't'
		    do_lcd_data 'o'
		    cp r22, temp2
		    breq step_end1
			mov temp, r22
		    inc temp
		    call display_station_number
		    rjmp go_on4
		    step_end1:
		        do_lcd_data '1'
		    go_on4:
		    do_lcd_data ':'
			clr r23
			rjmp get_numbers
	end_get_numbers:
	    // if already get time for each station, go to end
		cp r22, temp2
		breq end_get_times
		inc r22
		jmp get_times
	end_get_times:

	// boarder for steps
	// already got correct time to each station, stored in TimeToNext
	// going to get stop time at each station
	//  

		do_lcd_command 0b00111000 ; 2x5x7
		rcall sleep_5ms
		do_lcd_command 0b00111000 ; 2x5x7
		rcall sleep_1ms
		do_lcd_command 0b00111000 ; 2x5x7
		do_lcd_command 0b00111000 ; 2x5x7
		do_lcd_command 0b00001000 ; display off?
		do_lcd_command 0b00000001 ; clear display
		do_lcd_command 0b00000110 ; increment, no display shift
		do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	get_stop_time:
		do_lcd_data 'S'
		do_lcd_data 't'
		do_lcd_data 'o'
		do_lcd_data 'p'
		do_lcd_data ' '
		do_lcd_data 't'
		do_lcd_data 'i'
		do_lcd_data 'm'
		do_lcd_data 'e'
		do_lcd_data ':'
		call sleep_100ms
		call sleep_100ms
		call GetKeypadNumInput
		// only value between 2 and 5 is valid
		cpi temp, 2
		brlo error4
		cpi temp, 6
		brsh error4
        // store value and display
		sts StopTime, temp
		ldi temp1, 48
		add temp, temp1
		display
		call sleep_100ms
		call sleep_100ms
		// need to pressed D to confirm
		call GetKeypadNumInput
		cpi temp, 13
		breq end_get_stop_time
		error4:
		    do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_5ms
			do_lcd_command 0b00111000 ; 2x5x7
			rcall sleep_1ms
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00111000 ; 2x5x7
			do_lcd_command 0b00001000 ; display off?
			do_lcd_command 0b00000001 ; clear display
			do_lcd_command 0b00000110 ; increment, no display shift
			do_lcd_command 0b00001110 ; Cursor on, bar, no blink
			do_lcd_data 'X'
	end_get_stop_time:
	
	// boarder for steps
	// already got correct time to stop at each station, stored in StopTime
	// wait 5 seconds
	//  

	    do_lcd_command 0b00111000 ; 2x5x7
		rcall sleep_5ms
		do_lcd_command 0b00111000 ; 2x5x7
		rcall sleep_1ms
		do_lcd_command 0b00111000 ; 2x5x7
		do_lcd_command 0b00111000 ; 2x5x7
		do_lcd_command 0b00001000 ; display off?
		do_lcd_command 0b00000001 ; clear display
		do_lcd_command 0b00000110 ; increment, no display shift
		do_lcd_command 0b00001110 ; Cursor on, bar, no blink
		do_lcd_data 'W'
		do_lcd_data 'a'
		do_lcd_data 'i'
		do_lcd_data 't'
		do_lcd_data ' '
		do_lcd_data '5'
		do_lcd_data ' '
		do_lcd_data 's'
		do_lcd_data 'e'
		do_lcd_data 'c'
		do_lcd_data 'o'
		do_lcd_data 'n'
		do_lcd_data 'd'
		do_lcd_data 's'
	    // clear LED0-7
		clr leds
	    out PORTC, leds
		// sleep 5 seconds
		call sleep_1s
		call sleep_1s
		call sleep_1s
		call sleep_1s
		call sleep_1s
	// the emulation starts here

	ldi station, 1 ;start at station1
	ldi flag, 1 ;start with running
	clr counter
	clr stop_counter; used to count time and blink LED8-9 at right frequency
	mainloop:
	    call sleep_50ms ;sleep 1/10 second
		// if right amount of time passed, blink LED8-9
		mov temp, flag
		// if is at stop state
		cpi temp, 1
		breq no_change1
		inc stop_counter
			mov temp, stop_counter
			cpi temp, 3
			brne no_change1
			   clr stop_counter
			   // get one's compliment of the parttern of LED8-9
			   com blink
			   mov temp, blink
			   out PORTB, blink 	
		no_change1:
		call sleep_50ms
		// if right amount of time passed, blink LED8-9
		mov temp, flag
		// if is at stop state
		cpi temp, 1
		breq no_change2
			inc stop_counter
			mov temp, stop_counter
			cpi temp, 3
			brne no_change2
			   clr stop_counter
			   // get one's compliment of the parttern of LED8-9
			   com blink
			   mov temp, blink
			   out PORTB, blink 
		no_change2:
		cpi flag, 0 ; check if state is running
		breq stop_state1 ; flag == 0 means stop in station
		    rjmp running_state
		stop_state1:
		   jmp stop_state
		// when train is running, motter is running
		running_state:
		    // make sure turnning off LED8-9 
			clr blink
			out PORTB, blink
			ldi zl, low(TimeToNext)
	        ldi zh, high(TimeToNext)
			mov temp, station
			dec temp
			ldi temp1, 0
			add zl, temp ; make z point to right slot of time
			adc zh, temp1
			ld temp, z ; assign stop time to temp
			ldi temp2, 10 
			mul temp, temp2
			mov temp, r0 ; calculate how many loops should go throught
			cp counter, temp ; campare real and target num of loop
			brlo normal_go_on ; have not run through enough loop
			lds temp, MaxStations
			// check if is from last station to first station
			cp station, temp
			breq go_to_first
			inc station
			rjmp decide_stop
			go_to_first:
			    ldi station, 1
			decide_stop:
			cpi leds, 0
			breq no_stop
			    ldi flag, 0
				clr leds
				clr counter
				jmp mainloop
			no_stop:
			    ldi flag, 1
			    clr leds
				clr counter
				jmp mainloop
		// if train is stopping in a station, motter is not running
		stop_state:
		    // check if has stop enough time
			lds temp, StopTime
			ldi temp1, 10
			mul temp, temp1
			mov temp, r0
			cp counter, temp
			brlo normal_go_on
			ldi flag, 1
			clr counter
			jmp mainloop
		normal_go_on:
			call display_station_name ; display station name
			cpi flag, 1
			breq mot_on
			clr temp
			sts OCR3BL, temp ; if is stopping, make sure motor is turnning off
			rjmp go_on10
			mot_on:
			    ldi temp, 153
			    sts OCR3BL, temp ; set motter speed to be 60, this number to 0.6*255
			go_on10:

			update_leds:
			out PORTC, leds		
			// check if # has been pressed to halt train
			ldi mask, INITCOLMASK ; initial column mask
			clr col ; initial column
			colloop1:
				STS PORTL, mask ; set column to mask value
				; (sets column 0 off)
				ldi temp, 0xFF ; implement a delay so the
				; hardware can stabilize
				delay1:
					dec temp
					brne delay1
				LDS temp, PINL ; read PORTL. Cannot use in 
				andi temp, ROWMASK ; read only the row bits
				cpi temp, 0xF ; check if any rows are grounded
				breq nextcol1 ; if not go to the next column
				ldi mask, INITROWMASK ; initialise row check
				clr row ; initial row
				rowloop1:      
					mov temp1, temp
					and temp1, mask ; check masked bit
					brne skipconv1 ; if the result is non-zero,
					; we need to look again
					rjmp convert1 ; if bit is clear, convert the bitcode
					skipconv1:
					inc row ; else move to the next row
					lsl mask ; shift the mask to the next bit
					rjmp rowloop1          
				nextcol1:     
					cpi col, 3 ; check if we^Òre on the last column
					breq go_on_5 ; if so, no buttons were pushed,

					sec ; else shift the column mask:
					; We must set the carry bit
					rol mask ; and then rotate left by a bit,
					; shifting the carry into
					; bit zero. We need this to make
					; sure all the rows have
					; pull-up resistors
					inc col ; increment column value
					jmp colloop1 ; and check the next column
			; convert function converts the row and column given to a
			; binary number and also outputs the value to PORTC.
			; Inputs come from registers row and col and output is in
			; temp.
			convert1:
				cpi row, 3 ; if row is 3 we have a symbol or 0
				breq symbols1
				rjmp go_on_5 ; # is not pressed
				symbols1:
				cpi col, 2
				breq need_halt
				rjmp go_on_5 ; # is not pressed
				need_halt:
				    ldi temp, 1
					mov halt, temp
			go_on_5:
			    mov temp, halt
			    cpi temp, 0
				breq go_on_6
				    ldi temp, 0
				    sts OCR3BL, temp
					call sleep_500ms
					clr halt_counter
					// wait # being pressed, to start train again
				    call GetKeypadNumInput
					call sleep_100ms
					call sleep_100ms
					cpi temp, 15
					breq go_on_6
					rjmp go_on_5
			go_on_6:
			   clr halt
		inc counter
		jmp mainloop
	
	
// end here
// main function



//*************************************************************************************************************
// boarder for modules
//*************************************************************************************************************



// GetKeypadNumInput module, temp=0
// start here, get keypad input
// 0-9, A=0xA, B=0xB, C=0xC, D=0xD, *=0xE, #=0xF
; keeps scanning the keypad to find which key is pressed.
GetKeypadNumInput:
	run_again:
	//call sleep_1ms
	ldi r25, high(1996)
	ldi r24, low(1996)
	delayloop_1ms1:
		sbiw r25:r24, 1
		brne delayloop_1ms1
	mov temp, halt
	cpi temp, 1
	brne no_halt
	    inc halt_counter
		mov temp, halt_counter
		cpi temp, 17
		brne no_halt
		    com blink
		    out PORTB, blink 
	no_halt:
	ldi mask, INITCOLMASK ; initial column mask
	clr col ; initial column
	colloop:
		STS PORTL, mask ; set column to mask value
		; (sets column 0 off)
		ldi temp, 0xFF ; implement a delay so the
		; hardware can stabilize
		delay:
			dec temp
			brne delay
		LDS temp, PINL ; read PORTL. Cannot use in 
		andi temp, ROWMASK ; read only the row bits
		cpi temp, 0xF ; check if any rows are grounded
		breq nextcol ; if not go to the next column
		ldi mask, INITROWMASK ; initialise row check
		clr row ; initial row
		rowloop:      
			mov temp1, temp
			and temp1, mask ; check masked bit
			brne skipconv ; if the result is non-zero,
			; we need to look again
			rjmp convert ; if bit is clear, convert the bitcode
			skipconv:
			inc row ; else move to the next row
			lsl mask ; shift the mask to the next bit
			rjmp rowloop          
		nextcol:     
			cpi col, 3 ; check if we^Òre on the last column
			breq run_again ; if so, no buttons were pushed,
			; so start again.

			sec ; else shift the column mask:
			; We must set the carry bit
			rol mask ; and then rotate left by a bit,
			; shifting the carry into
			; bit zero. We need this to make
			; sure all the rows have
			; pull-up resistors
			inc col ; increment column value
			jmp colloop ; and check the next column
	; convert function converts the row and column given to a
	; binary number and also outputs the value to PORTC.
	; Inputs come from registers row and col and output is in
	; temp.
	convert:
		cpi col, 3 ; if column is 3 we have a letter
		breq letters
		cpi row, 3 ; if row is 3 we have a symbol or 0
		breq symbols
		mov temp, row ; otherwise we have a number (1-9)
		lsl temp ; temp = row * 2
		add temp, row ; temp = row * 3
		add temp, col ; add the column address
		; to get the offset from 1
		inc temp ; add 1. Value of switch is
		; row*3 + col + 1.
		jmp convert_end
		letters:
		ldi temp, 0xA
		add temp, row ; increment from 0xA by the row value
		jmp convert_end
		symbols:
		cpi col, 0 ; check if we have a star
		breq star
		cpi col, 1 ; or if we have zero
		breq zero
		ldi temp, 0xF ; we'll output 0xF for hash
		jmp convert_end
		star:
		ldi temp, 0xE ; we'll output 0xE for star
		jmp convert_end
		zero:
		clr temp ; set to zero
		convert_end:
		//out PORTC, temp ; write value to PORTC
		ret ; return to caller
// end here
// GetKeypadNumInput



//*************************************************************************************************************
// boarder for modules
//*************************************************************************************************************



// display station number
// start here, station number stored in temp
display_station_number:
    push temp1
	cpi temp, 10
	breq equal_ten
	ldi temp1, 48
	add temp, temp1
	display
	sub temp, temp1
	pop temp1
	ret
	equal_ten:
	do_lcd_data '1'
	do_lcd_data '0'
	pop temp1
	ret
// end here
// 


//*************************************************************************************************************
// boarder for modules
//*************************************************************************************************************



// display station name
// start here, current station number stored in station, display the name of next station 
display_station_name:
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
    ldi zl, low(StationNames)
	ldi zh, high(StationNames)
	ldi xl, low(MaxStations)
	ldi xh, high(MaxStations)
	ld temp2, x
	cp station, temp2
	brlo not_last
	rjmp if_last
	// current station is not the last
	not_last:
		mov temp, station
		ldi temp1, 10
		mul temp, temp1
		mov temp, r0
		clr temp1
		// make z point to right name
		add zl, temp
		adc zh, temp1
	// current station is the last
	if_last:
	    ldi temp1, 1
	next_display:
	    cpi temp1, 11
		breq end_display
		ld temp, z+
		display
		inc temp1
		rjmp next_display
    end_display:
	ret
// end here
// display station name



//*************************************************************************************************************
// boarder for modules
//*************************************************************************************************************



// LCD setting and displaying module
// start here
	.equ LCD_RS = 7
	.equ LCD_E = 6
	.equ LCD_RW = 5
	.equ LCD_BE = 4

	.macro lcd_set
		sbi PORTA, @0
	.endmacro
	.macro lcd_clr
		cbi PORTA, @0
	.endmacro

	;
	; Send a command to the LCD (r16)
	;

	lcd_command:
		out PORTF, r16
		nop
		lcd_set LCD_E
		nop
		nop
		nop
		lcd_clr LCD_E
		nop
		nop
		nop
		ret

	lcd_data:
		out PORTF, r16
		lcd_set LCD_RS
		nop
		nop
		nop
		lcd_set LCD_E
		nop
		nop
		nop
		lcd_clr LCD_E
		nop
		nop
		nop
		lcd_clr LCD_RS
		ret

	lcd_wait:
		push r16
		clr r16
		out DDRF, r16
		out PORTF, r16
		lcd_set LCD_RW
	lcd_wait_loop:
		nop
		lcd_set LCD_E
		nop
		nop
			nop
		in r16, PINF
		lcd_clr LCD_E
		sbrc r16, 7
		rjmp lcd_wait_loop
		lcd_clr LCD_RW
		ser r16
		out DDRF, r16
		pop r16
		ret

	.equ F_CPU = 16000000
	.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
	; 4 cycles per iteration - setup/call-return overhead

	sleep_1ms:
		push r24
		push r25
		ldi r25, high(DELAY_1MS)
		ldi r24, low(DELAY_1MS)
	delayloop_1ms:
		sbiw r25:r24, 1
		brne delayloop_1ms
		pop r25
		pop r24
		ret

	sleep_5ms:
		rcall sleep_1ms
		rcall sleep_1ms
		rcall sleep_1ms
		rcall sleep_1ms
		rcall sleep_1ms
		ret

	sleep_10ms:
	    rcall sleep_5ms
		rcall sleep_5ms
		ret

    sleep_50ms:
	    rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		ret

	sleep_100ms:
	    rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		rcall sleep_10ms
		ret


    sleep_500ms:
	    rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		ret

	sleep_1s:
	    rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		rcall sleep_100ms
		ret
// end here
// LCD setting and displaying module




