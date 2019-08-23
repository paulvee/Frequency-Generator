; Frequency Selection
;
; This program gets driven by a rotary encoder with a pushbutton.
; The selection of the encoder ranges between 20MHz 
; and 1Hz. The pushbutton turns the Fast Rise power on and off. 
;
; When the selections reaches either end, it
; will stay at that value and not move on.
; The frequency setting will be send as a string to
; an 8 x 2 LCD display.
;
; Display:
;        1 2 3 4 5 6 7 8
;Line 1: F r e q - G e n
; or
;Line 1: F a s t R i s e
;Line 2: _ X X X _ K H z (_Hz/MHz)
;
;
#picaxe 14M2
#no_data
;
;#DEFINE debug	; main code

#rem
; Set I/O pins
;
; Rotary Encoder:
; A = C.0 IN (pin 1) needs interrupt
; B = C.1 IN (pin 3) Keep grouped, easier to mask
; P = C.3 IN (pin 4) C3 is input only!
;
; Frequency dividers:
; /1 = B.1 OUT
; /2 = B.2 OUT
; /4 = B.3 OUT
;
; Frequency selection (74LS151):
; A = C.4 OUT
; B = C.2 OUT
; C = B.5 OUT
;
#endrem
; Freq Selection outputs are active low
; 
; INPUT  C.0, C.1 Rotary Encoder
; OUTPUT C.2, C.4
; INPUT  C.3 Rotaray Encode Pushbutton
; INPUT  C.5 RX - used by in circuit programming
DIRSC = %010100 ; 0=input, 1=output
;
; OUTPUT B.0 = TX - by using SEROUT, we can also use the serial LCD during debug (output ONLY!)
; OUTPUT B.1 = /1 Freq selection
; OUTPUT B.2 = /2 Freq selection
; OUTPUT B.3 = /4 Freq selection
; OUTPUT B.4 FastRise power
; OUTPUT B.5 74LS151 C output selection
DIRSB = %111111 ; 0=input, 1 = output
;

;
; used variables
; bit vars
SYMBOL getBits  = b0 	; C.0=A and C.1=B of the rotary decoder
SYMBOL rotEnc	= b1	; B.4 Rotary Encoder Switch
SYMBOL FastRise	= b3	; Fast Rise Board on|off
; byte vars
SYMBOL dir      = b4	; direction (left|right)
SYMBOL savepos 	= b5	; previous value of rotary position
SYMBOL fpos		= b6	; rotary decoder counter & position
; constants
SYMBOL FastRPwr = B.4	; Fast Rise Board Power
;
; PIC Settings
; Baud rate is set in conjunction with the clockspeed (default is 4MHz)
; Chip frequency is set in INIT: to 16 MHz.
;
SYMBOL baud	= N2400_16
#DEFINE SerPrint SEROUT B.0, baud, 

; interrupt definition
setint %00000001, %00000001 ,C 'set interrupt on C.0 (rot enc-A) going high

main: 
	#IFDEF debug
		; no need
	#ELSE
		; We'll give it some time here, the LCD itself needs to fully boot too
		;PAUSE 1000
	#ENDIF

	; start with initialising the board
	GOSUB init

	DO	
		; while in this loop, we can get an interrupt coming from the rotary decoder
		; only update when we have a new setting

		IF fpos <> savepos THEN ; we must have a new setting
			GOSUB update
			savepos = fpos ; store the previous position
		ENDIF
		
		;Check for a rotary switch pushbutton press (active high)
		IF PinC.3 = 1 THEN
			Pause 20 ; debounce delay
			do while PinC.3 = 1 ;now wait for the button to be released
				Pause 2 		;to finish the full cycle
			loop
			; toggle the FastRise board power on and off 

			IF FastRise = 1 THEN
				FastRise = 0 ; is on, turn off
				Low FastRPwr
				SerPrint ($FE,$80)
				SerPrint ("Freq Gen")
			ELSE
				FastRise = 1 ; is off, turn on
				High FastRPwr
				SerPrint ($FE,$80)
				SerPrint ("FastRise")
			ENDIF
		ENDIF	

		PAUSE 100
		
	LOOP ; forever

END

init:
	; send the software version to the display and
	; initialise the board to a known state
	;
	; the freq selection outputs are active high
	OUTPINSC = %000000 ; A, B, C
	; the divider outputs B1, B2, B3 are active low
	; B4 switches the Fast Rise board power to off (active high)
	; B5 freq selection active high
	OUTPINSB = %001110 ; /1, /2, /4

	;
	#IFDEF debug
		; clear the screen
		SerPrint ($FE,$01)
	#ENDIF
	;
	; PIC Settings
	SETFREQ M16 ; m1, m2, m4(default), m8, m16, m32
	PAUSE 5000	; needs some settling down
	;
	; go to start of Line 1 on LCD
	SerPrint ($FE,$80)
	; send the welcome message to the display
	SerPrint ("Freq Gen")
	; go to the start of the second line
	SerPrint ($FE,$C0)
	SerPrint ("  V2.1  ")
	
	PAUSE 5000 ; display the welcome message for 5 seconds

	; go back to start of Line 1 on LCD
	SerPrint ($FE,$80)
	; send the header to the first line
	SerPrint ("Freq Gen")

	; set the frequency position to 1KHz as a starting setting
	fpos = 14
	; turn off the power to the FastRise board
	Low FastRPwr ; FastRise power off
	FastRise = 0

	; update the settings and send to the display
	GOSUB update
	savepos = fpos ; now we wait for a change
	;
return	

update:
	#rem 
	Update the frequency settings and send it to the display
	
	Whenever the rotary decoder is turned, the new setting will
	be displayed.
	
	The rotary encoder interrupt code limits the minimum and 
	maximum vpos values.
	
	all strings are 8 characters to fill Line 2 completely
	
	The serial msg is made up of 8 byte strings going to the
	display:
	
	Line 2: _ X X X _ K H z _

	#endrem
	;
	
	SEROUT B.0, baud, ($FE, $C0) ; go to start of Line 2
	;

	SELECT CASE fpos
		
	CASE <= 1 ; 20MHz
			PinC.2 = 0	;A
			PinC.4 = 0	;B
			PinB.5 = 0	;C
			; /1 = 20MHz
			PinB.1 = 0
			PinB.2 = 1
			PinB.3 = 1
			SerPrint ("  20 MHz") ; Send string to the LCD display
			
	CASE = 2 ; 10MHz
			PinC.2 = 0	;A
			PinC.4 = 0	;B
			PinB.5 = 0	;C
			; 20MHz /2
			PinB.1 = 1
			PinB.2 = 0
			PinB.3 = 1
			SerPrint ("  10 MHz")
			
	CASE = 3 ; 5MHz
			PinC.2 = 0	;A
			PinC.4 = 0	;B
			PinB.5 = 0	;C
			; 20MHz /4 
			PinB.1 = 1
			PinB.2 = 1
			PinB.3 = 0
			SerPrint ("   5 MHz")
			
	CASE = 4 ; 2MHz
			PinC.2 = 1	;A
			PinC.4 = 0	;B
			PinB.5 = 0	;C
			; 20MHz / 1 
			PinB.1 = 0
			PinB.2 = 1
			PinB.3 = 1
			SerPrint ("   2 MHz") 
			
	CASE = 5 ; 1MHz
			PinC.2 = 1	;A
			PinC.4 = 0	;B
			PinB.5 = 0	; 
			; 2MHz /2 
			PinB.1 = 1
			PinB.2 = 0
			PinB.3 = 1
			SerPrint ("   1 MHz")
			
	CASE = 6 ; 500KHz
			PinC.2 = 1	;A
			PinC.4 = 0	;B
			PinB.5 = 0	;C
			; 2MHZ /4 
			PinB.1 = 1
			PinB.2 = 1
			PinB.3 = 0
			SerPrint (" 500 KHz")
			
	CASE = 7 ; 200KHz
			PinC.2 = 0	;A
			PinC.4 = 1	;B
			PinB.5 = 0	;C
			; 200KHz /1 
			PinB.1 = 0
			PinB.2 = 1
			PinB.3 = 1 
			SerPrint (" 200 KHz")
			
	CASE = 8 ; 100KHz
			PinC.2 = 0	;A
			PinC.4 = 1	;B
			PinB.5 = 0	;C
			; 200KHz /2 
			PinB.1 = 1
			PinB.2 = 0
			PinB.3 = 1 
			SerPrint (" 100 KHz")
			
	CASE = 9 ; 50KHz
			PinC.2 = 0	;A
			PinC.4 = 1	;B
			PinB.5 = 0	;C
			; 200KHz /4 
			PinB.1 = 1
			PinB.2 = 1
			PinB.3 = 0
			SerPrint ("  50 KHz")
			
	CASE = 10 ; 20KHz
			PinC.2 = 1	;A
			PinC.4 = 1	;B
			PinB.5 = 0	;C
			; 20KHz /1  
			PinB.1 = 0
			PinB.2 = 1
			PinB.3 = 1
			SerPrint ("  20 KHz")
			
	CASE = 11 ; 10KHz
			PinC.2 = 1	;A
			PinC.4 = 1	;B
			PinB.5 = 0	;C
			; 20KHz /2 
			PinB.1 = 1
			PinB.2 = 0
			PinB.3 = 1
			SerPrint ("  10 KHz")
			
	CASE = 12 ; 5KHz
			PinC.2 = 1	;A
			PinC.4 = 1	;B
			PinB.5 = 0	;C
			; 20KHz /4 
			PinB.1 = 1
			PinB.2 = 1
			PinB.3 = 0
			SerPrint ("   5 KHz")
			
	CASE = 13 ; 2KHz
			PinC.2 = 0	;A
			PinC.4 = 0	;B
			PinB.5 = 1	;C
			; 2KHz /1 
			PinB.1 = 0
			PinB.2 = 1
			PinB.3 = 1
			SerPrint ("   2 KHz")
			
	CASE = 14 ; 1KHz
			PinC.2 = 0	;A
			PinC.4 = 0	;B
			PinB.5 = 1	;C
			; 2KHz /2 
			PinB.1 = 1
			PinB.2 = 0
			PinB.3 = 1
			SerPrint ("   1 KHz")
			
	CASE = 15 ; 500Hz
			PinC.2 = 0	;A
			PinC.4 = 0	;B
			PinB.5 = 1	;C
			; 2KHz /4 
			PinB.1 = 1
			PinB.2 = 1
			PinB.3 = 0 
			SerPrint (" 500 Hz ")
			
	CASE = 16 ; 200Hz
			PinC.2 = 1	;A
			PinC.4 = 0	;B
			PinB.5 = 1	;C
			; 200Hz /1 
			PinB.1 = 0
			PinB.2 = 1
			PinB.3 = 1 
			SerPrint (" 200 Hz ")
			
	CASE = 17 ; 100Hz
			PinC.2 = 1	;A
			PinC.4 = 0	;B
			PinB.5 = 1	;C
			; 200Hz /2 
			PinB.1 = 1
			PinB.2 = 0
			PinB.3 = 1
			SerPrint (" 100 Hz ")
			
	CASE = 18 ; 50Hz
			PinC.2 = 1	;A
			PinC.4 = 0	;B
			PinB.5 = 1	;C
			; 200Hz /4 
			PinB.1 = 1
			PinB.2 = 1
			PinB.3 = 0 
			SerPrint ("  50 Hz ")
			
	CASE = 19 ; 20Hz
			PinC.2 = 0	;A
			PinC.4 = 1	;B
			PinB.5 = 1	;C
			; 20Hz /1 
			PinB.1 = 0
			PinB.2 = 1
			PinB.3 = 1	
			SerPrint ("  20 Hz ")
			
	CASE = 20 ; 10Hz
			PinC.2 = 0	;A
			PinC.4 = 1	;B
			PinB.5 = 1	;C
			; 20Hz /2 
			PinB.1 = 1
			PinB.2 = 0
			PinB.3 = 1
			SerPrint ("  10 Hz ")
			
	CASE = 21 ; 5Hz
			PinC.2 = 0	;A
			PinC.4 = 1	;B
			PinB.5 = 1	;C
			; 20Hz /4 
			PinB.1 = 1
			PinB.2 = 1
			PinB.3 = 0
			SerPrint ("   5 Hz ")
			
	CASE = 22 ; 2Hz
			PinC.2 = 1	;A
			PinC.4 = 1	;B
			PinB.5 = 1	;C
			; 2Hz /1 
			PinB.1 = 0
			PinB.2 = 1
			PinB.3 = 1 
			SerPrint ("   2 Hz ")
			
	CASE = 23 ; 1Hz
			PinC.2 = 1	;A
			PinC.4 = 1	;B
			PinB.5 = 1	;C
			; 2Hz /2 
			PinB.1 = 1
			PinB.2 = 0
			PinB.3 = 1 
			SerPrint ("   1 Hz ")

	ENDSELECT

	PAUSE 100 ; Allow message to update
	
RETURN

; Rotary Encoder
;
#rem
http://www.picaxeforum.co.uk/archive/index.php/t-13590.html

Rotary encoder connection:

                0V
                |
               4.7K (pull down resistor)
                |
encoder pin1 o--.----o -1K- Picaxe 08M pin1 C.0
encoder pin2 o---- +5V
encoder pin3 o--.----o -1K- Picaxe 08M pin2 C.1
                |
               4.7K (pull down resistor)
                |
                0V

Encoder result (early detection):
pin1 pin2
  1    0  one direction
  0    1  other direction
  0    0  init and final (= "detent") status

One direction: pin1 goes high before pin2
         ___     ___
pin1 ___|   |___|   |___
           ___     ___
pin2 _____|   |___|   |___

Other direction: pin2 goes high before pin1
           ___     ___
pin1 _____|   |___|   |___
         ___     ___
pin2 ___|   |___|   |___

#endrem
;
interrupt:
; on entry, the interrupt is disabled, need to set it again at the end
;
	PAUSE 1 ; circumvent a bug in the microcode. First statement should not assign vars.
	
	PINSC = getBits ;read the rotary encoder pins
	bit1 = pinC.1
	bit0 = pinC.0 ;save rotary encode status

	getBits = getBits & %000000011 ;isolate the two rotary encoder pins
	
	if getBits <> 0 then ;if both pins are low, direction is undetermined : discard
		dir = bit1 * 2 ;direction: if bit2=low then dir=0=up; if bit2=high then dir=2=down
		fpos = fpos - 1 + dir ;change counter with -1 or +1
	
		; WATCH OUT, if the decoder is in the wrong state, this loop will hang the system!
		
		do while getBits <> 0 ;now wait for the encoder to go to the next indent position
			getBits = PINSC & %00000011 ;to finish the full cycle
		loop
	endif
	; check for the end ranges
	IF fpos >= 23 THEN ;minimum is 1Hz
		fpos = 23 ; keep it there
	ENDIF
	IF fpos <= 1 THEN ;maximum is 20MHz
		fpos = 1 ; keep it there
	ENDIF
	PAUSE 100 ; wait a little before we turn the ints back on to keep the display from flashing
	setint %00000001, %00000001 ,C ;restore the interrupt on C.0 going high

return 

