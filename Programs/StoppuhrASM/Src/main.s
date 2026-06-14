;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf	
;* Version            : V1.0
;* Date               : 11.05.2022
;* Description        : Rahmen zur Loesung von GTP Woche 7-9 (Stoppuhr).
;* 
;* Team               : Jan Klindtworth      	Matrikel-Nr. 2884053                                        
;*						Xuan Hoang Duy Trinh 	Matrikel-Nr. 2881544 
;*   
;*******************************************************************************

;********************************************
; Peripherie-Adressen
;******************************************** #

PERIPH_BASE     	equ	0x40000000                 ;Startadresse 
AHB1PERIPH_BASE 	equ	(PERIPH_BASE + 0x00020000)
APB1PERIPH_BASE     equ PERIPH_BASE

GPIOD_BASE			equ	(AHB1PERIPH_BASE + 0x0C00)
GPIOF_BASE			equ	(AHB1PERIPH_BASE + 0x1400)
TIM2_BASE           equ (APB1PERIPH_BASE + 0x0000)
	
GPIO_F_PIN        	equ	(GPIOF_BASE + 0x10)

GPIO_D_PIN			equ	(GPIOD_BASE + 0x10)
GPIO_D_SET			equ (GPIOD_BASE + 0x18)
GPIO_D_CLR			equ	(GPIOD_BASE + 0x1A)
	
TIMER				equ (TIM2_BASE + 0x24)   ; aktueller Zeitstempel (32 bit)
TIM2_PSC			equ (TIM2_BASE + 0x28)   ; 
TIM2_ERG			equ (TIM2_BASE + 0x14)   ; Timerneustart

;********************************************
; Bitmasken für LEDs und Buttons  
;********************************************

STATUS_INIT			equ 0	
STATUS_RUN			equ 1
STATUS_HOLD			equ 2


;********************************************
; Bitmasken für LEDs, Bit 0 = D8, Bit 1 = D9 und Buttons, Bit=0 --> Taster Gedrückt   
;********************************************



LED_D8				equ (1 << 1)    		; Zeitmessung aktiv
LED_D9              equ (1 << 2)    		; Hold aktiv

button_S5			equ	0xDF    		; Reset -> INIT
button_S6			equ 0xBF			; Stop  -> HOLD
button_S7			equ 0x7F			; Start -> RUN

;********************************************
; Externe Funktionen  
;********************************************

    EXTERN initITSboard
    EXTERN GUI_init
	EXTERN TP_Init
	EXTERN initTimer
	EXTERN lcdSetFont
	EXTERN lcdGotoXY      		; TFT goto x y function
	EXTERN lcdPrintS			; TFT output function	
    EXTERN lcdPrintC            ; TFT output one character		
	EXTERN Delay				; Delay (ms) function

;********************************************
; Datensegment (4-Byte Grenze), Textstartzustand 
;********************************************

	AREA MyData, DATA, align = 2

DEFAULT_BRIGHTNESS	DCW     800

TIMER_TEXT			DCB		"00:00:00", 0
TEXT_TITEL			DCB		"-- Stoppuhr --", 0
ZEIT				DCB		"00:00:00", 0



VAR_MM_Z			DCB		0
VAR_MM_E			DCB		0
VAR_SS_Z			DCB		0
VAR_SS_E			DCB		0
VAR_NN_Z			DCB		0
VAR_NN_E			DCB		0




	; Variablen für Woche 2: 
STATE				DCD		STATUS_INIT		; aktueller Zustand der Finite State Machine (FSM) 
ZEITDIFFERENZ		DCD		0				: gestoppte Zeitspanne in Ticks



;********************************************
; Datensegment (8-Byte Grenze)
;********************************************
	AREA |.text|, CODE, READONLY, ALIGN = 3




;--------------------------------------------
; main subroutine
;--------------------------------------------




	EXPORT main [CODE]
	
main	PROC

		; --- Hardware-Initialisierung ---
		BL		initITSboard

		ldr   	r1, =DEFAULT_BRIGHTNESS
		ldrh 	r0, [r1]
		bl   	GUI_init

		bl  	initTimer

		ldr 	R1,=TIM2_PSC   			; Set pre scaler such that 1 timer tick represents 10 us
		mov 	R0,#(90*10-1) 
		strh	R0,[R1]

		ldr 	R1,=TIM2_ERG   			; Restart timer	
		mov		R0,#0x01
		strh	R0,[R1]					; Set UG Bit

		MOV 	R0, #24
		bl  	lcdSetFont

		; Ihre Initialisierung
		LDR		R1, = STATE
		MOV		R0, #STATUS_INIT
		strb	R0, [R1]
		
	 	;BL 		UpdateClk

;--------------------------------------------
; Hauptschleife: superloop
;--------------------------------------------
superloop
		BL		UpdateClk				
		BL 		readButtons
		LDR		R1, =STATE
		LDR		R2, [R1]				

		CMP		R2, #STATUS_RUN
		BEQ		do_run

		CMP		R2, #STATUS_HOLD
		BEQ		do_hold

		CMP		R2, #STATUS_INIT
		BEQ		do_init				

		BAL		superloop
do_run
		BL		run
		BAL		superloop
do_hold
		BL		hold
		BAL		superloop
do_init
		BL		init
		BAL		superloop		

		ENDP

;--------------------------------------------
; Unterprogramm: readButtons
;--------------------------------------------

readButtons PROC
		push	{lr}
		ldr		R0,=GPIO_F_PIN
		ldrh	R0,[R0]

		ldr		R2, =State
		ldrh	R1, [R2]

testS5
		AND		R3, R0, #button_S5
		cmp		R3, #0
		bne 	testS6
		mov		R1, #STATUS_INIT
		strh	R1,[R2]
		BAL		readButtons_ende

testS6
		AND		R3, R0, #button_S6
		CMP		R3, #0
		bne		testS7
		CMP		R1, #STATUS_RUN
		bne		testS7
		mov		R1, #STATUS_HOLD
		strh	R1,[R2]
		BAL		readButtons_ende
	
testS7
		AND		R3, R0, #button_S7
		CMP		R3, #0
		bne		readButtons_ende
		CMP		R1, #STATUS_RUN
		beq 	readButtons_ende
		mov 	R1, #STATUS_RUN
		strh	R1,[R2]

readButtons_ende
		pop		{PC}

		ENDP

		
;--------------------------------------------
; Unterprogramm: run
;--------------------------------------------
run		PROC
		push	{lr}

		LDR		R1, =STOPZEIT
		LDR		R2, [R1]
		ADD		R2, R2, R0
		STR		R2, [R1]

		MOV		R0, R2
		BL		displayZeit

		LDR		R1, =GPIO_D_SET
		mov		R0, #LED_D8
		strh	R0, [R1]
		LDR		R1, =GPIO_D_CLR
		mov		R0, #LED_D9
		strh	R0, [R1]

		bl		readButtons
		tst		R0, #button_S6
		bne		run_check_s5			
		LDR		R1, =STATE
		MOV		R2, #STATUS_HOLD
		STR		R2, [R1]
		B		run_ende

run_check_s5
		tst		R0, #button_S5
		bne		run_ende				
		LDR		R1, =STATE
		MOV		R2, #STATUS_INIT
		STR		R2, [R1]

run_ende
		pop		{lr}
		bx		lr
		ENDP

;--------------------------------------------
; Unterprogramm: hold
;--------------------------------------------

zeitRechnung PROC
		PUSH 	{R4,R5,R6,R7,lr}
		
		ldr		R1, LAST_TICK
		ldr		R4,[R1]

		ldr 	R5, =TIMER_TEXT





initDisplay PROC

		push	{lr}
		mov		R0, #0
		mov		R1, #0

		bl		lcdGotoXY
		ldr 	R0, =TEXT_TITEL
		bl 		lcdPrintS

		mov		R0, #0
		mov		R1, #1

		bl		lcdGotoXY
		ldr		R0, =TEXT_START
		bl 		lcdPrintS

		pop 	{lr}
		bx		lr
		ENDP


		ALIGN
		END

