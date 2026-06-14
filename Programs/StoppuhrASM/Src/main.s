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

PERIPH_BASE     	equ	0x40000000                 									; Startadresse 
AHB1PERIPH_BASE 	equ	(PERIPH_BASE + 0x00020000)
APB1PERIPH_BASE     equ PERIPH_BASE

GPIOD_BASE			equ	(AHB1PERIPH_BASE + 0x0C00)									; Basisadresse für LEDs
GPIOF_BASE			equ	(AHB1PERIPH_BASE + 0x1400)									; Basisadresse für Taster
TIM2_BASE           equ (APB1PERIPH_BASE + 0x0000)									; Basisadresse für Timer
	
GPIO_F_PIN        	equ	(GPIOF_BASE + 0x10)											; Register zum Lesen der Taster
GPIO_D_PIN			equ	(GPIOD_BASE + 0x10)											; Register zum Lesen der LED-Zustände	
GPIO_D_SET			equ (GPIOD_BASE + 0x18)											; Adresse zum Einschalten der LEDs
GPIO_D_CLR			equ	(GPIOD_BASE + 0x1A)											; Adresse zum Ausschalten der LEDs
	
TIMER				equ (TIM2_BASE + 0x24)   										; Aktueller Zeitstempel (32 Bit)
TIM2_PSC			equ (TIM2_BASE + 0x28)   										; Timerteiler
TIM2_ERG			equ (TIM2_BASE + 0x14)   										; Timerneustart

;********************************************
; Bitmasken für LEDs, Bit 0 = D8, Bit 1 = D9 und Buttons, Bit=0 --> Taster Gedrückt   
;********************************************
STATUS_INIT			equ 0															; Zustand: Uhr zurückgesetzt
STATUS_RUN			equ 1															; Zustand: Uhr läuft
STATUS_HOLD			equ 2															; Zustand: Anzeige gestoppt

LED_D8				equ (1 << 0)    												; Zeitmessung aktiv
LED_D9              equ (1 << 1)    												; Hold aktiv

button_S5			equ (1 << 5)    												; Reset -> INIT
button_S6			equ (1 << 6)													; Stop  -> HOLD
button_S7			equ (1 << 7)													; Start -> RUN  

;********************************************
; Externe Funktionen  
;********************************************
    EXTERN initITSboard
    EXTERN GUI_init
	EXTERN TP_Init
	EXTERN initTimer
	EXTERN lcdSetFont
	EXTERN lcdGotoXY      															; Cursor positionieren
	EXTERN lcdPrintS																; String ausgeben	
    EXTERN lcdPrintC            													; Ein Zeichen ausgeben		
	EXTERN Delay																	

;********************************************
; Datensegment (4-Byte Grenze), Textstartzustand 
;********************************************
	AREA MyData, DATA, ALIGN = 2

DEFAULT_BRIGHTNESS	DCW     800
MY_TEXT				DCB		"Hold down different buttons from S0 to S7 and watch D8 to D15.", 0

TIMER_TEXT			DCB		"00:00.00", 0
TITEL_TEXT			DCB		"-- Stoppuhr --", 0

VAR_MM_Z            DCB     0 														; Minuten Zehner
VAR_MM_E            DCB     0 														; Minuten Einer
VAR_SS_Z            DCB     0 														; Sekunden Zehner
VAR_SS_E            DCB     0 														; Sekunden Einer
VAR_NN_Z            DCB     0 														; Hundertstel Zehner
VAR_NN_E            DCB     0														; Hundertstel Einer

	; --- Variablen für Woche 2 --- 
STATE				DCD		STATUS_INIT												; Aktueller Zustand 
TIMEDIFFERENCE		DCD		0														; Gestoppte Zeitspanne in Ticks
LAST_TICK			DCD		0														; Zeitstempel beim letzten Durchlauf	

;********************************************
; Datensegment (8-Byte Grenze)
;********************************************
	AREA |.text|, CODE, READONLY, ALIGN = 4

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

		ldr 	R1,=TIM2_PSC   														; Timer-Teiler setzen, damit 1 Tick = 10 µs entspricht
		mov 	R0,#(90*10-1) 
		strh	R0,[R1]

		ldr 	R1,=TIM2_ERG   														; Timer	neu starten
		mov		R0,#0x01
		strh	R0,[R1]																

		mov 	R0, #24
		bl  	lcdSetFont

		bl		initDisplay

		; --- LEDs D8 und D9 ausschalten ---
		mov     R3, #(LED_D8 :OR: LED_D9)	
		ldr		R1,=GPIO_D_CLR
		strh	R3, [R1]															; Bits in CLR-Register schreiben schaltet LEDs aus

	 	bl 		UpdateClk

;--------------------------------------------
; Hauptschleife: superloop
;--------------------------------------------
superloop
		bl		UpdateClk															; Zeitspanne seit letztem Aufruf berechnen	

		ldr		R1, =STATE
		ldr		R2, [R1]				

		CMP		R2, #STATUS_RUN
		beq		do_run

		cmp		R2, #STATUS_HOLD
		beq		do_hold

		cmp		R2, #STATUS_INIT
		beq		do_init				

		bal		superloop	
do_init
		bl		init
		bal		superloop	
do_run
		bl		run
		bal		superloop
do_hold
		bl		hold
		bal		superloop															

		ENDP

;--------------------------------------------
; Unterprogramm: initDisplay
;--------------------------------------------
initDisplay PROC

		push	{lr}																; Rücksprungadresse retten			
		mov		R0, #0																; X-Position 0
		mov		R1, #0																; Y-Position 0		
		bl		lcdGotoXY															; Cursor oben links
		ldr 	R0, =TITEL_TEXT
		bl 		lcdPrintS															; Titel ausgeben

		mov		R0, #0												
		mov		R1, #1																; Zeile 1

		bl		lcdGotoXY
		ldr		R0, =TIMER_TEXT
		bl 		lcdPrintS															; Startzeit ausgeben

		pop 	{lr}																; Rücksprung
		bx		lr
		ENDP
		
;--------------------------------------------
; Unterprogramm: readButtons
;--------------------------------------------
readButtons PROC
        push    {lr}
        ldr     R0,=GPIO_F_PIN														; Taster-Status lesen
        ldrh    R0,[R0]

        ldr     R2, =STATE															; Aktuellen Status laden
        ldrh    R1, [R2]

testS5
        AND     R3, R0, #button_S5
        cmp     R3, #0
        bne     testS6																; Wenn Bit gesetzt (nicht gedrückt), zum nächsten
        mov     R1, #STATUS_INIT
        strh    R1,[R2]																; Zustand auf INIT setzen
        BAL     readButtons_ende

testS6
        AND     R3, R0, #button_S6
        CMP     R3, #0
        bne     testS7
        CMP     R1, #STATUS_RUN
        bne     testS7																; Wenn Bit gesetzt (nicht gedrückt), zum nächsten
        mov     R1, #STATUS_HOLD
        strh    R1,[R2]																; Zustand auf HOLD setzen
        BAL     readButtons_ende

testS7
        AND     R3, R0, #button_S7
        CMP     R3, #0
        bne     readButtons_ende
        CMP     R1, #STATUS_RUN
        beq     readButtons_ende
        mov     R1, #STATUS_RUN
        strh    R1,[R2]																; Zustand auf RUN setzen

readButtons_ende
        pop     {PC}
        ENDP

;--------------------------------------------
; Unterprogramm: displayZeit
;--------------------------------------------		
displayZeit PROC

		push	{lr}
		
		;--- 10 Minuten = 60 000 000 Ticks ---
		ldr		R1, = 60000000
		udiv	R2, R0, R1															; R2 = Zehner-Stelle der Minuten
		mls		R0, R2, R1, R0														; R0 = Rest (verbleibende Ticks)
		ldr 	R3, =VAR_MM_Z
		strb	R2, [R3]

		;-- 1 Minute = 6 000 000 Ticks ---
		ldr		R1, = 6000000
		udiv	R2, R0, R1															; R2 = Einer-Stelle der Minuten
		mls		R0, R2, R1, R0														; R0 = Rest
		ldr 	R3, =VAR_MM_E
		strb	R2, [R3]

		;---10 Sekunden = 1 000 000 Ticks ---
		ldr		R1, = 1000000
		udiv	R2, R0, R1															; R2 = Zehner-Stelle der Sekunden
		mls		R0, R2, R1, R0														; R0 = Rest
		ldr 	R3, =VAR_SS_Z
		strb	R2, [R3]

		;--- 1 Sekunde = 100 000 Ticks ---
		ldr		R1, = 100000
		udiv	R2, R0, R1															; R2 = Einer-Stelle der Sekunden
		mls		R0, R2, R1, R0														; R0 = Rest (< 100 000 Ticks = < 1 Sekunde)
		ldr 	R3, =VAR_SS_E
		strb	R2, [R3]

		;--- Hundertstel (nn): Rest in 10ms-Schritte umrechnen ---
		ldr		R1, = 1000
		udiv	R2, R0, R1															; R2 = nn gesamt (0-99)
		;Ziffernteiler
		mov		R1, #10
		udiv	R3, R2, R1															; R3 = nn / 10 (Zehner)
		mls		R2, R3, R1, R2														; R2 = nn mod 10 (Einer)
		ldr 	R1, =VAR_NN_Z
		strb	R3, [R1]
		ldr 	R1, =VAR_NN_E
		strb	R2, [R1]

;--------------------------------------------
; Displayausgabe  
;--------------------------------------------
		;--- Minutenausgabe ---
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

		;--- Trennzeichen ':' ---

		mov		R0, #':'
		bl		lcdPrintC

		;--- Sekundenausgabe ---
		ldr		R0, =VAR_SS_Z
		ldrb	R0, [R0]
		add		R0, R0, #'0'
		bl 		lcdPrintC

		ldr		R0, =VAR_SS_E
		ldrb	R0, [R0]
		add		R0, R0, #'0'
		bl 		lcdPrintC

		;--- Trennzeichen '.' ---

		mov		R0, #'.'
		bl		lcdPrintC

		;--- Nanosekundeausgabe ---
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

;--------------------------------------------
; Unterprogramm: UpdateClk
;--------------------------------------------
UpdateClk	PROC
		push	{lr}

		ldr		R1, =TIMER															; Aktuellen Timer-Wert laden
		ldr		R2, [R1]

		ldr		R1, =LAST_TICK														; Alten Zeitstempel laden
		ldr 	R3, [R1]

		sub		R0, R2, R3															; Differenz berechnen
		str		R2, [R1]															; Aktuellen Timer als neuen "Letzten" speichern

		pop		{lr}
		bx		lr
		ENDP
		
;--------------------------------------------
; Unterprogramm: init
;--------------------------------------------
init	PROC
		push {lr}

		; Zeit auf 0 zurücksetzen
		ldr		R1, =TIMEDIFFERENCE		
		mov		R2, #0
		str		R2, [R1]
		mov		R0, #0
		bl		displayZeit

		; LEDs ausschalten
		ldr		R1, =GPIO_D_CLR
		mov		R0, #(LED_D8 :OR: LED_D9)
		strh	R0, [R1]

		; Prüfen ob S7 gedrückt, dann direkt in RUN	
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

;--------------------------------------------
; Unterprogramm: run
;--------------------------------------------
run		PROC
		push	{lr}

		; Zeit aufaddieren
		ldr		R1, =TIMEDIFFERENCE
		ldr		R2, [R1]
		add		R2, R2, R0
		str		R2, [R1]

		; Zeit anzeigen
		mov		R0, R2
		bl		displayZeit

		; LED D8 an, D9 aus
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

		; Zeit weiterzählen (aber nicht ausgeben)
		ldr		R1, =TIMEDIFFERENCE
		ldr		R2, [R1]
		add		R2, R2, R0
		str		R2, [R1]

		; LEDs D8 und D9 an
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

		ALIGN
		END