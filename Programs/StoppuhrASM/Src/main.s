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

; änderungen nötig


STATUS_INIT			equ 0	
STATUS_RUN			equ 1
STATUS_HOLD			equ 2


;********************************************
; Bitmasken für LEDs, Bit 0 = D8, Bit 1 = D9 und Buttons, Bit=0 --> Taster Gedrückt   
;********************************************

; änderungen nötig

LED_D8				equ (1 << 1)    		; Zeitmessung aktiv
LED_D9              equ (1 << 2)    		; Hold aktiv

button_S5			equ (1 << 5)    		; Reset -> INIT
button_S6			equ (1 << 6)			; Stop  -> HOLD
button_S7			equ (1 << 7)			; Start -> RUN

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
MY_TEXT				DCB		"Hold down different buttons from S0 to S7 and watch D8 to D15.", 0

TEXT_START			DCB		"00:00:00", 0
TEXT_TITEL			DCB		"-- Stoppuhr --", 0

VAR_MM_Z			DCB		0
VAR_MM_E			DCB		0
VAR_SS_Z			DCB		0
VAR_SS_E			DCB		0
VAR_NN_Z			DCB		0
VAR_NN_E			DCB		0

	; Variablen für Woche 2: 

STATE				DCD		STATE_INIT		; aktueller Zustand der Finite State Machine (FSM) 
STOPZEIT			DCD		0				; gestoppte Zeitspanne in Ticks
LAST_TICK			DCD		0				; Zeitstempel beim letzten Aufruf	
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
		bl		initITSboard

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

		mov 	R0, #24
		bl  	lcdSetFont

		; Ihre Initialisierung
		ldr		R1, = STATE
		mov		R0, #STATUS_INIT
		strb	R0, [R1]
		
	 	bl 		UpdateClk

;--------------------------------------------
; Hauptschleife: superloop
;--------------------------------------------
superloop
		bl		UpdateClk				

		ldr		R1, =STATE
		ldr		R2, [R1]				

		CMP		R2, #STATUS_RUN
		beq		do_run

		cmp		R2, #STATUS_HOLD
		beq		do_hold

		cmp		R2, #STATUS_INIT
		beq		do_init				

		bal		superloop
do_run
		bl		run
		bal		superloop
do_hold
		bl		hold
		bal		superloop
do_init
		bl		init
		bal		superloop		

		ENDP

;--------------------------------------------
; Unterprogramm: UpdateClk
;--------------------------------------------
UpdateClk	PROC
		push	{lr}

		ldr		R1, =TIMER
		ldr		R2, [R1]

		ldr		R1, =LAST_TICK
		ldr 	R3, [R1]

		sub		R0, R2, R3
		str		R2, [R1]

		pop		{lr}
		bx		lr
		ENDP

;--------------------------------------------
; Unterprogramm: readButtons
;--------------------------------------------
readButtons PROC
        push    {lr}
        ldr        R0,=GPIO_F_PIN
        ldrh    R0,[R0]

        ldr        R2, =State
        ldrh    R1, [R2]

testS5
        AND        R3, R0, #button_S5
        cmp        R3, #0
        bne     testS6
        mov        R1, #STATUS_INIT
        strh    R1,[R2]
        BAL        readButtons_ende

testS6
        AND        R3, R0, #button_S6
        CMP        R3, #0
        bne        testS7
        CMP        R1, #STATUS_RUN
        bne        testS7
        mov        R1, #STATUS_HOLD
        strh    R1,[R2]
        BAL        readButtons_ende

testS7
        AND        R3, R0, #button_S7
        CMP        R3, #0
        bne        readButtons_ende
        CMP        R1, #STATUS_RUN
        beq     readButtons_ende
        mov     R1, #STATUS_RUN
        strh    R1,[R2]

readButtons_ende
        pop        {PC}

        ENDP

;--------------------------------------------
; Unterprogramm: run
;--------------------------------------------
run		PROC
		push	{lr}

		ldr		R1, =STOPZEIT
		ldr		R2, [R1]
		add		R2, R2, R0
		str		R2, [R1]

		mov		R0, R2
		bl		displayZeit

		ldr		R1, =GPIO_D_SET
		mov		R0, #LED_D8
		strh	R0, [R1]
		ldr		R1, =GPIO_D_CLR
		mov		R0, #LED_D9
		strh	R0, [R1]

		bl		readButtons
		tst		R0, #button_S6
		bne		run_check_s5			
		ldr		R1, =STATE
		mov		R2, #STATUS_HOLD
		str		R2, [R1]
		b		run_ende

run_check_s5
		tst		R0, #button_S5
		bne		run_ende				
		ldr		R1, =STATE
		mov		R2, #STATUS_INIT
		str		R2, [R1]

run_ende
		pop		{lr}
		bx		lr
		ENDP

;--------------------------------------------
; Unterprogramm: hold
;--------------------------------------------
hold 	PROC
		push	{lr}

		ldr		R1, =STOPZEIT
		ldr		R2, [R1]
		add		R2, R2, R0
		str		R2, [R1]

		ldr		R1, =GPIO_D_SET
		mov		R0, #(LED_D8 :OR: LED_D9)
		strh	R0, [R1]

		bl		readButtons
		tst		R0, #button_S5
		bne		hold_check_s7
		ldr		R1, =STATE
		mov		R2, #STATUS_INIT
		str		R2, [R1]
		b		hold_ende

hold_check_s7
		tst		R0, #button_S7
		bne		hold_ende				
		ldr		R1, =STATE
		mov		R2, #STATUS_RUN
		str		R2, [R1]

hold_ende
		pop		{lr}
		bx		lr
		ENDP

;--------------------------------------------
; Unterprogramm: init
;--------------------------------------------
init	PROC
		push {lr}

		ldr		R1, STOPZEIT
		mov		R2, #0
		str		R2, [R1]
		mov		R0, #0
		bl		displayZeit

		ldr		R1, =GPIO_D_CLR
		mov		R0, #(LED_D8 :OR: LED_D9)
		strh	R0, [R1]

		bl		readButtons
		tst		R0, #button_S7
		bne		init_ende
		ldr		R1, =STATE
		mov		R2, #STATUS_RUN
		str		R2, [R1]

init_ende
		pop		{lr}
		bx		lr
		ENDP




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

		
displayZeit PROC

		push	{lr}

		;------- Minuten (mm)-------

		;--Minuten gesamt--
		ldr		R1, =TICK_PRO_MINUTE
		udiv	R2, R0, R1					; R2 = Ticks / 60 000 000 ohne Rest

		; mm = mm gesamt mod 60
		mov		R3, #60
		udiv	R1, R2, R3					; R1 = R2 / 60
		mls		R2, R1, R3, R2				; R2 = mm (0-59)

		;Ziffernteiler
		mov		R3, #10
		udiv	R1, R2, R3					; R1 = mm / 10 (Zehner)
		mls		R3, R1, R3, R2				; R3 = mm mod 10 (Einer) --> R3 Neuer Wert

		ldr 	R2, =VAR_MM_Z
		strb	R1, [R2]
		ldr 	R2, =VAR_MM_E
		strb	R3, [R2]

		;------- Sekunden (ss)-------

		;--Sekunden gesamt--
		ldr		R1, =TICK_PRO_SEKUNDE
		udiv	R2, R0, R1					; R2 = Ticks / 100000 ohne Rest

		; ss = ss gesamt mod 60
		mov		R3, #60
		udiv	R1, R2, R3					; R1 = R2 / 60
		mls		R2, R1, R3, R2				; R2 = ss (0-59)

		;Ziffernteiler
		mov		R3, #10
		udiv	R1, R2, R3					; R1 = ss / 10 (Zehner)
		mls		R3, R1, R3, R2				; R3 = ss mod 10 (Einer) --> R3 Neuer Wert

		ldr 	R2, =VAR_SS_Z
		strb	R1, [R2]
		ldr 	R2, =VAR_SS_E
		strb	R3, [R2]

		;------- Nanosekunde (nn)-------

		;--Nanosekunde gesamt--
		ldr		R1, =TICK_PRO_NANO
		udiv	R2, R0, R1					; R2 = Ticks / 1000 ohne Rest

		; nn = nn gesamt mod 100
		mov		R3, #100
		udiv	R1, R2, R3					; R1 = R2 / 100
		mls		R2, R1, R3, R2				; R2 = nn (0-99)

		;Ziffernteiler
		mov		R3, #10
		udiv	R1, R2, R3					; R1 = nn / 10 (Zehner)
		mls		R3, R1, R3, R2				; R3 = nn mod 10 (Einer) --> R3 Neuer Wert

		ldr 	R2, =VAR_NN_Z
		strb	R1, [R2]
		ldr 	R2, =VAR_NN_E
		strb	R3, [R2]

		; Alle Werte liegen im RAM desshalb darf R0 überschrieben werden mit BL-Aufrufe


		; Minuten
		mov		R0, #0
		mov 	R1, #1
		bl 		lcdGotoXY

		ldr		R0, =VAR_MM_Z
		ldrb	R0, [R0]
		add		R0, R0, #'0'
		bl 		lcdPrintC

		ldr		R0, =VAR_MM_E
		ldrb	R0, [R0]
		add		R0, R0, #'0'
		bl 		lcdPrintC

		; Trennzeichen ';'

		mov		R0, #';'
		bl		lcdPrintC

		;Sekunden
		ldr		R0, =VAR_SS_Z
		ldrb	R0, [R0]
		add		R0, R0, #'0'
		bl 		lcdPrintC

		ldr		R0, =VAR_SS_E
		ldrb	R0, [R0]
		add		R0, R0, #'0'
		bl 		lcdPrintC

		; Trennzeichen ';'

		mov		R0, #';'
		bl		lcdPrintC

		;Nanosekunde
		ldr		R0, =VAR_NN_Z
		ldrb	R0, [R0]
		add		R0, R0, #'0'
		bl 		lcdPrintC

		ldr		R0, =VAR_NN_E
		ldrb	R0, [R0]
		add		R0, R0, #'0'
		bl 		lcdPrintC

		pop		{lr}
		bx		lr
		ENDP

		ALIGN
		END

