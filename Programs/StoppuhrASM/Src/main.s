;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf	
;* Version            : V1.0
;* Date               : 11.05.2022
;* Description        : Rahmen zur Lösung von GTP Woche 7-9 (Stoppuhr).
;* 
;* Team               : Jan Klindtworth      	Matrikel-Nr. 2884053                                        
;*						Xuan Hoang Duy Trinh 	Matrikel-Nr. 2881544 
;*   
;*******************************************************************************

;********************************************
; Peripherie-Adressen
;******************************************** #

PERIPH_BASE     	equ	0x40000000                 									; Startadresse des gesamten Peripherie-Speicherbereichs
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

LED_D8				equ (1 << 0)    												; Bit 0 = LED D8 (Zeitmessung aktiv)
LED_D9              equ (1 << 1)    												; Bit 1 = LED D9 (Hold aktiv)

button_S5			equ (1 << 5)    												; Bit 5 = Taster (Reset -> INIT)
button_S6			equ (1 << 6)													; Bit 6 = Taster S6 (Stop  -> HOLD)
button_S7			equ (1 << 7)													; Bit 7 = Taster S7 (Start -> RUN)  

;********************************************
; Externe Funktionen
;********************************************

    EXTERN initITSboard																; initialisiert das gesamte ITS-Board (Takte, Pins, Display)
    EXTERN GUI_init																	; initialisiert die grafische Oberfläche des TFT-Displays
	EXTERN TP_Init																	; initialisiert den Touchscreen (hier ungenutzt)
	EXTERN initTimer																; initialisiert den Timer-Baustein
	EXTERN lcdSetFont																; stellt die Schriftgröße des Displays ein
	EXTERN lcdGotoXY																; Cursor positionieren: R0 = X-Spalte, R1 = Y-Zeile
	EXTERN lcdPrintS																; String ausgeben: R0 = Adresse des Strings	
    EXTERN lcdPrintC            													; ein einzelnes Zeichen ausgeben: R0 = ASCII-Wert		
	EXTERN Delay																	; wartet eine angegebene Anzahl Millisekunden: R0 = Millisekunden															

;********************************************
; Datensegment (4-Byte Grenze), Textstartzustand 
;********************************************
	AREA MyData, DATA, ALIGN = 2

DEFAULT_BRIGHTNESS	DCW     800
MY_TEXT				DCB		"Hold down different buttons from S0 to S7 and watch D8 to D15.", 0

TIMER_TEXT			DCB		"00:00.00", 0											; Anfangstext der Stoppuhr-Anzeige, wird beim Start einmal ausgegeben
TITEL_TEXT			DCB		"-- Stoppuhr --", 0										; Überschrift, die oben auf dem Display steht

VAR_MM_Z            DCB     0 														; Minuten-Zehner
VAR_MM_E            DCB     0 														; Minuten-Einer
VAR_SS_Z            DCB     0 														; Sekunden-Zehner
VAR_SS_E            DCB     0 														; Sekunden-Einer
VAR_NN_Z            DCB     0 														; Hundertstel-Zehner
VAR_NN_E            DCB     0														; Hundertstel-Einer

LAST_MM_Z           DCB     0xFF													; zuletzt angezeigte Minuten-Zehnerstelle
LAST_MM_E           DCB     0xFF													; zuletzt angezeigte Minuten-Einerstelle
LAST_SS_Z           DCB     0xFF													; zuletzt angezeigte Sekunden-Zehnerstelle
LAST_SS_E           DCB     0xFF													; zuletzt angezeigte Sekunden-Einerstelle
LAST_NN_Z           DCB     0xFF													; zuletzt angezeigte Hundertstel-Zehnerstelle
LAST_NN_E           DCB     0xFF													; zuletzt angezeigte Hundertstel-Einerstelle

; --- Variablen für die Zustandsmaschine (FSM) ---
ALIGN																				; sorgt dafür, dass die nächste Variable auf einer durch 4 teilbaren Adresse liegt wegen DCD = 32 Bit
STATE				DCD		STATUS_INIT												; aktueller Zustand der FSM (0=INIT, 1=RUN, 2=HOLD)
TIMEDIFFERENCE		DCD		0														; gestoppte Zeitspanne in Ticks (1 Tick = 10us)
LAST_TICK			DCD		0														; Zeitstempel des Timers beim letzten UpdateClk-Aufruf	

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
		bl		initITSboard														; Board komplett initialisieren (Takte, GPIO-Pins, Display-Controller)
		ldr   	r1, =DEFAULT_BRIGHTNESS												; Adresse der Helligkeits-Variable laden
		ldrh 	r0, [r1]															; 16-Bit-Wert (800) aus dem RAM in R0 laden
		bl   	GUI_init															; grafische Oberfläche mit dieser Helligkeit initialisieren
		bl  	initTimer															; Timer-Baustein initialisieren
 
		ldr 	R1,=TIM2_PSC   														; Adresse des Prescaler-Registers laden
		mov 	R0,#(90*10-1) 														; Teilerwert berechnen, damit 1 Timer-Tick = 10 Mikrosekunden entspricht
		strh	R0,[R1]																; Teilerwert in das Prescaler-Register schreiben (16 Bit)
 
		ldr 	R1,=TIM2_ERG   														; Adresse des Neustart-Registers laden
		mov		R0,#0x01															; Bitmuster für das UG-Bit (Update Generation)
		strh	R0,[R1]																; UG-Bit setzen -> Timer startet bei 0 neu
 
		mov 	R0, #24																; gewünschte Schriftgröße
		bl  	lcdSetFont															; Schriftgröße auf dem Display einstellen
 
		bl		initDisplay															; Titel und Start-Anzeige einmalig ausgeben
 
		; --- LEDs D8 und D9 zu Beginn ausschalten ---
		mov     R3, #(LED_D8 :OR: LED_D9)											; Bitmaske für beide LEDs (Bit 0 + Bit 1 = 0x03)
		ldr		R1,=GPIO_D_CLR														; Adresse des "Ausschalten"-Registers laden
		strh	R3, [R1]															; Bits in das Register schreiben -> beide LEDs gehen aus
 
	 	bl 		UpdateClk															; LAST_TICK einmalig mit aktuellem Timer-Wert füllen, damit der erste Schleifendurchlauf keine riesige Zeitspanne berechnet
 
;--------------------------------------------
; Hauptschleife: superloop
;--------------------------------------------
superloop
		bl		UpdateClk															; Zeitspanne seit letztem Durchlauf berechnen, Ergebnis steht in R0
		ldr		R1, =STATE															; Adresse der Zustandsvariable laden
		ldr		R2, [R1]															; aktuellen Zustand (0/1/2) in R2 laden
 
		cmp		R2, #STATUS_RUN														; Zustand mit STATUS_RUN vergleichen 
		bleq	run																	; Nur wenn Z-Flag gesetzt (R2==STATUS_RUN): run aufrufen, danach hierher zurück
 
		cmp		R2, #STATUS_HOLD													; Zustand mit STATUS_HOLD vergleichen
		bleq	hold																; Nur wenn gleich: hold aufrufen, danach hierher zurück
 
		cmp		R2, #STATUS_INIT													; Zustand mit STATUS_INIT vergleichen
		bleq	init																; Nur wenn gleich: init aufrufen, danach hierher zurück
 
		bal		superloop															; zurück zum Schleifenanfang
		ENDP
 
;--------------------------------------------
; Unterprogramm: initDisplay
; Aufgabe: Titel und Start-Anzeige einmalig auf dem TFT ausgeben
;--------------------------------------------
initDisplay PROC
		push	{lr}																; Rücksprungadresse retten (da dieses Unterprogramm selbst BL aufruft)
 
		mov		R0, #0																; X-Position = Spalte 0
		mov		R1, #0																; Y-Position = Zeile 0
		bl		lcdGotoXY															; Cursor auf Zeile 0, Spalte 0 setzen
		ldr 	R0, =TITEL_TEXT														; Adresse des Titeltextes laden
		bl 		lcdPrintS															; Titeltext ausgeben
 
		mov		R0, #0																; X-Position = Spalte 0
		mov		R1, #1																; Y-Position = Zeile 1
		bl		lcdGotoXY															; Cursor auf Zeile 1, Spalte 0 setzen
		ldr		R0, =TIMER_TEXT														; Adresse des Start-Zeit-Textes laden
		bl 		lcdPrintS															; Startzeit "00:00.00" ausgeben
 
		pop 	{lr}																; Rücksprungadresse zurückholen
		bx		lr																	; zurück zum Linkregister springen
		ENDP
 
;--------------------------------------------
; Unterprogramm: readButtons
; Aufgabe: liest nur den Taster-Zustand und gibt ihn zurück
; Ausgabe: R0 = Taster-Register (Bit=0 bedeutet "gedrückt")
;--------------------------------------------
readButtons PROC
        push    {lr}																; Rücksprungadresse retten
        ldr     R0,=GPIO_F_PIN														; Lade die Adresse des Taster-Lese-Registers in R0
        ldrh    R0,[R0]																; Lade den Wert von dieser Adresse -> R0 enthält jetzt den Zustand ALLER 8 Taster als Bitmuster; Bit=0 heisst "gedrückt"

        ldr     R2, =STATE															; Lade die Adresse von STATE in R2
        ldrh    R1, [R2]															; Lade den aktuellen Wert von STATE in R1

testS5
        and     R3, R0, #button_S5													; R3 = R0 UND Bitmaske (Bit 5) -> isoliert nur Bit 5, alle anderen Bits werden zu 0
        cmp     R3, #0																; Vergleiche R3 mit der Konstante 0 
        bne     testS6																; Wenn Bit gesetzt (nicht gedrückt, R3 != 0), zum nächsten
        mov     R1, #STATUS_INIT													; Wenn S5 gedrückt war (Bit 5 = 0) -> R1 = 0 (STATUS_INIT)
        strh    R1,[R2]																; Schreibe den neuen Zustand (INIT) in die Variable STATE
        bal     readButtons_ende													; Springe direkt zum Ende, S6/S7 müssen nicht mehr geprüft werden, S5 hat Vorrang

testS6
        and     R3, R0, #button_S6													; R3 = R0 UND Bitmaske (Bit 6) -> isoliert Bit 6
        cmp     R3, #0																; Vergleiche R3 mit der Konstante 0
        bne     testS7																; Wenn Bit 6 = 1 (S6 nicht gedrückt), weiter zu S7
        cmp     R1, #STATUS_RUN														; Ist S6 gedrückt, prüfe zusätzlich: ist der aktuelle Zustand RUN
        bne     testS7																; Wenn nicht im RUN-Zustand, hat S6 keine Wirkung -> weiter zu S7
        mov     R1, #STATUS_HOLD													; Wenn S6 gedrückt UND Zustand war RUN -> R1 = 2 (STATUS_HOLD)
        strh    R1,[R2]																; Schreibe den neuen Zustand (HOLD) in die Variable STATE
        bal     readButtons_ende													: Springe zum Ende

testS7
        and     R3, R0, #button_S7													; R3 = R0 UND Bitmaske (Bit 7) -> isoliert Bit 7
        cmp     R3, #0																; Vergleiche R3 mit der Konstante 0
        bne     readButtons_ende													; Wenn Bit 7 = 1 (S7 nicht gedrückt), nichts zu tun -> Ende
        cmp     R1, #STATUS_RUN														; Ist S7 gedrückt, prüfe: ist der Zustand bereits RUN?
        beq     readButtons_ende													; Wenn schon RUN, ist nichts zu ändern -> Ende
        mov     R1, #STATUS_RUN														; Wenn S7 gedrückt UND noch nicht RUN: R1 = 1 (STATUS_RUN)
        strh    R1,[R2]																; Schreibe den neuen Zustand (RUN) in die Variable STATE

readButtons_ende
        pop     {PC}																; Hole die geretteten LR vom Stack und schreibe ihn DIREKT in den Program Counter
        ENDP

;--------------------------------------------
; Unterprogramm: displayZeit
; Aufgabe: rechnet die übergebene Tick-Zahl in mm:ss.nn um und gibt nur diejenigen Ziffern neu auf dem Display aus, die sich seit dem letzten Aufruf tatsächlich geändert haben 
; Eingabe : R0 = Zeit in Ticks (1 Tick = 10 Mikrosekunden)
;--------------------------------------------		
displayZeit PROC
		push	{lr}																; Rücksprungadresse retten
		
		;--- 10 Minuten = 60 000 000 Ticks ---
		ldr		R1, = 60000000														; Teiler laden
		udiv	R2, R0, R1															; R2 = R0 / R1 = Zehnerstelle der Minuten
		mls		R0, R2, R1, R0														; R0 = R0 - (R2 * R1) = Rest (verbleibende Ticks unter 10 Minuten)
		ldr 	R3, =VAR_MM_Z														; Adresse der Ziel-Variable laden
		strb	R2, [R3]															; berechnete Ziffer in VAR_MM_Z speichern (1 Byte)

		;-- 1 Minute = 6 000 000 Ticks ---
		ldr		R1, = 6000000														; Teiler laden
		udiv	R2, R0, R1															; R2 = Einerstelle der Minuten (0-9, da Rest aus vorigem Schritt < 10 Minuten ist)
		mls		R0, R2, R1, R0														; R0 = neuer Rest
		ldr 	R3, =VAR_MM_E														; Adresse der Ziel-Variable laden
		strb	R2, [R3]															; berechnete Ziffer speichern

		;---10 Sekunden = 1 000 000 Ticks ---
		ldr		R1, = 1000000														; Teiler laden
		udiv	R2, R0, R1															; R2 = Zehnerstelle der Sekunden
		mls		R0, R2, R1, R0														; R0 = neuer Rest
		ldr 	R3, =VAR_SS_Z														; Adresse der Ziel-Variable laden
		strb	R2, [R3]															; berechnete Ziffer speichern

		;--- 1 Sekunde = 100 000 Ticks ---
		ldr		R1, = 100000														; Teiler laden
		udiv	R2, R0, R1															; R2 = Einerstelle der Sekunden
		mls		R0, R2, R1, R0														; R0 = Rest (jetzt < 100 000 Ticks = < 1 Sekunde)
		ldr 	R3, =VAR_SS_E														; Adresse der Ziel-Variable laden
		strb	R2, [R3]															; berechnete Ziffer speichern
 
		;--- Hundertstel (nn): Rest in 10ms-Schritte umrechnen ---
		ldr		R1, = 1000															; Teiler laden: 1 Hundertstel = 1000 Ticks
		udiv	R2, R0, R1															; R2 = Hundertstel gesamt (0-99)
		mov		R1, #10																; jetzt klassisch in Zehner/Einer aufteilen
		udiv	R3, R2, R1															; R3 = Zehnerstelle der Hundertstel
		mls		R2, R3, R1, R2														; R2 = Einerstelle der Hundertstel (Rest)
		ldr 	R1, =VAR_NN_Z														; Adresse der Ziel-Variable laden
		strb	R3, [R1]															; Zehnerstelle speichern
		ldr 	R1, =VAR_NN_E														; Adresse der Ziel-Variable laden
		strb	R2, [R1]															; Einerstelle speichern
 

;--------------------------------------------
; Überprüfung und Ausgabe auf dem Display  
;--------------------------------------------
		;--- Minuten Zehnerstelle prüfen und ggf. ausgeben ---
		ldr		R0, =VAR_MM_Z														; Adresse der neu berechneten Ziffer laden
		ldrb	R0, [R0]															; Ziffer (0-9) in R0 laden
		ldr		R1, =LAST_MM_Z														; Adresse der zuletzt angezeigten Ziffer laden
		ldrb	R2, [R1]															; zuletzt angezeigte Ziffer in R2 laden
		cmp		R0, R2																; neue Ziffer mit alter Ziffer vergleichen
		beq		check_mm_e															; gleich -> nichts zu tun, weiter zur nächsten Stelle
		strb	R0, [R1]															; sonst: LAST_MM_Z auf den neuen Wert aktualisieren
		mov		R3, R0																; Ziffer für später rettet (wird durch lcdGotoXY überschrieben)
		mov		R0, #0																; X-Position der Minuten-Zehnerstelle auf dem Display
		mov		R1, #1																; Y-Position = Zeile 1 (Zeitanzeige)
		bl		lcdGotoXY															; Cursor an die richtige Stelle setzen
		mov		R0, R3																; gerettete Ziffer zurückholen
		add		R0, R0, #'0'														; Ziffer (Zahl) in ASCII-Zeichen umwandeln
		bl		lcdPrintC															; Zeichen auf dem Display ausgeben
 
check_mm_e
		;--- Minuten Einerstelle prüfen und ggf. ausgeben ---
		ldr		R0, =VAR_MM_E
		ldrb	R0, [R0]
		ldr		R1, =LAST_MM_E
		ldrb	R2, [R1]
		cmp		R0, R2
		beq		check_ss_z
		strb	R0, [R1]
		mov		R3, R0
		mov		R0, #1																; X-Position der Minuten-Einerstelle
		mov		R1, #1
		bl		lcdGotoXY
		mov		R0, R3
		add		R0, R0, #'0'
		bl		lcdPrintC
 
check_ss_z
		;--- Sekunden Zehnerstelle prüfen und ggf. ausgeben ---
		ldr		R0, =VAR_SS_Z
		ldrb	R0, [R0]
		ldr		R1, =LAST_SS_Z
		ldrb	R2, [R1]
		cmp		R0, R2
		beq		check_ss_e
		strb	R0, [R1]
		mov		R3, R0
		mov		R0, #3																; X-Position der Sekunden-Zehnerstelle (nach mm + ':' = 2 Stellen Versatz)
		mov		R1, #1
		bl		lcdGotoXY
		mov		R0, R3
		add		R0, R0, #'0'
		bl		lcdPrintC
 
check_ss_e
		;--- Sekunden Einerstelle prüfen und ggf. ausgeben ---
		ldr		R0, =VAR_SS_E
		ldrb	R0, [R0]
		ldr		R1, =LAST_SS_E
		ldrb	R2, [R1]
		cmp		R0, R2
		beq		check_nn_z
		strb	R0, [R1]
		mov		R3, R0
		mov		R0, #4																; X-Position der Sekunden-Einerstelle
		mov		R1, #1
		bl		lcdGotoXY
		mov		R0, R3
		add		R0, R0, #'0'
		bl		lcdPrintC
 
check_nn_z
		;--- Hundertstel Zehnerstelle prüfen und ggf. ausgeben ---
		ldr		R0, =VAR_NN_Z
		ldrb	R0, [R0]
		ldr		R1, =LAST_NN_Z
		ldrb	R2, [R1]
		cmp		R0, R2
		beq		check_nn_e
		strb	R0, [R1]
		mov		R3, R0
		mov		R0, #6																; X-Position der Hundertstel-Zehnerstelle
		mov		R1, #1
		bl		lcdGotoXY
		mov		R0, R3
		add		R0, R0, #'0'
		bl		lcdPrintC
 
check_nn_e
		;--- Hundertstel Einerstelle prüfen und ggf. ausgeben ---
		ldr		R0, =VAR_NN_E
		ldrb	R0, [R0]
		ldr		R1, =LAST_NN_E
		ldrb	R2, [R1]
		cmp		R0, R2
		beq		displayZeit_ende
		strb	R0, [R1]
		mov		R3, R0
		mov		R0, #7																; X-Position der Hundertstel-Einerstelle
		mov		R1, #1
		bl		lcdGotoXY
		mov		R0, R3
		add		R0, R0, #'0'
		bl		lcdPrintC
 
displayZeit_ende
		pop		{lr}																; Rücksprungadresse zurückholen
		bx		lr																	; zurück zum Linkregister springen
		ENDP

;--------------------------------------------
; Unterprogramm: UpdateClk
; Aufgabe: liest den Timer aus und berechnet, wie viele Ticks seit dem letzten Aufruf vergangen sind
; Ausgabe: R0 = vergangene Ticks seit dem letzten Aufruf
;--------------------------------------------
UpdateClk	PROC
		push	{lr}																; Rücksprungadresse retten
		
		ldr		R1, =TIMER															; Adresse des Timer-Registers laden
		ldr		R2, [R1]															; aktuellen Timer-Wert (Zeitstempel) in R2 laden

		ldr		R1, =LAST_TICK														; Adresse der Variable mit dem alten Zeitstempel laden
		ldr 	R3, [R1]															; alten Zeitstempel in R3 laden

		sub		R0, R2, R3															; Differenz berechnen = vergangene Ticks seit letztem Aufruf
		str		R2, [R1]															; aktuellen Zeitstempel als neuen "letzten" Wert speichern, für nächsten Aufruf

		pop		{lr}																; Rücksprungadresse zurückholen
		bx		lr																	; zurück zum Linkregister springen, Ergebnis steht in R0
		ENDP
 
;--------------------------------------------
; Unterprogramm: init
; Aufgabe: Zustand INIT - Stoppuhr auf 0 zurücksetzen, auf Start warten
; Eingabe : R0 = Zeitspanne seit letztem Aufruf (wird hier nicht gebraucht)
;--------------------------------------------
init	PROC
		push 	{lr}																; Rücksprungadresse retten
 
		; --- Zeit auf 0 zurücksetzen ---
		ldr		R1, =TIMEDIFFERENCE													; Adresse der Zeitvariable laden
		mov		R2, #0																; Wert 0
		str		R2, [R1]															; TIMEDIFFERENCE = 0
		mov		R0, #0																; Parameter für displayZeit: 0 Ticks
		bl		displayZeit															; Anzeige auf 00:00.00 zurücksetzen
 
		; --- LEDs ausschalten ---
		ldr		R1, =GPIO_D_CLR														; Adresse des "Ausschalten"-Registers laden
		mov		R0, #(LED_D8 :OR: LED_D9)											; Bitmaske für beide LEDs
		strh	R0, [R1]															; beide LEDs ausschalten
 
		; --- Prüfen ob S7 gedrückt, dann Wechsel nach RUN ---
		bl		readButtons															; aktuellen Taster-Zustand in R0 lesen
		tst		R0, #button_S7														; Bit 7 (S7) testen
		bne		init_ende															; Bit=1 -> S7 NICHT gedrückt -> nichts tun, Ende
		ldr		R1, =STATE															; sonst (Bit=0, S7 gedrückt): Adresse der Zustandsvariable laden
		mov		R2, #STATUS_RUN														; neuer Zustand: RUN
		str		R2, [R1]															; STATE = STATUS_RUN
init_ende
		pop		{lr}																; Rücksprungadresse zurückholen
		bx		lr																	; zurück zum Linkregister springen
		ENDP
 
;--------------------------------------------
; Unterprogramm: run
; Aufgabe: Zustand RUNNING - Zeit läuft, Anzeige wird aktualisiert
; Eingabe : R0 = Zeitspanne (Ticks) seit letztem UpdateClk-Aufruf
;--------------------------------------------
run		PROC
		push	{lr}																; Rücksprungadresse retten
 
		; --- Zeit aufaddieren ---
		ldr		R1, =TIMEDIFFERENCE													; Adresse der Zeitvariable laden
		ldr		R2, [R1]															; bisherigen Wert laden
		add		R2, R2, R0															; vergangene Ticks (R0) dazuzählen
		str		R2, [R1]															; neuen Wert zurückspeichern
 
		; --- Zeit anzeigen ---
		mov		R0, R2																; aktuellen Zeitwert als Parameter für displayZeit vorbereiten
		bl		displayZeit															; Anzeige aktualisieren (nur veränderte Ziffern werden neu gezeichnet)
 
		; --- LED D8 an, D9 aus ---
		ldr		R1, =GPIO_D_SET														; Adresse des "Einschalten"-Registers laden
		mov		R0, #LED_D8															; Bitmaske für D8
		strh	R0, [R1]															; D8 einschalten
		ldr		R1, =GPIO_D_CLR														; Adresse des "Ausschalten"-Registers laden
		mov		R0, #LED_D9															; Bitmaske für D9
		strh	R0, [R1]															; D9 ausschalten
 
		; --- Taster prüfen: S6 -> HOLD, S5 -> INIT ---
		bl		readButtons															; aktuellen Taster-Zustand in R0 lesen
		tst		R0, #button_S6														; Bit 6 (S6) testen
		bne		run_check_s5														; Bit=1 -> S6 NICHT gedrückt -> weiter zu S5-Prüfung
		ldr		R1, =STATE															; sonst (S6 gedrückt): Adresse der Zustandsvariable laden
		mov		R2, #STATUS_HOLD													; neuer Zustand: HOLD
		str		R2, [R1]															; STATE = STATUS_HOLD
		b		run_ende															; fertig
 
run_check_s5
		tst		R0, #button_S5														; Bit 5 (S5) testen
		bne		run_ende															; Bit=1 -> S5 NICHT gedrückt -> nichts tun
		ldr		R1, =STATE															; sonst (S5 gedrückt): Adresse der Zustandsvariable laden
		mov		R2, #STATUS_INIT													; neuer Zustand: INIT
		str		R2, [R1]															; STATE = STATUS_INIT
 
run_ende
		pop		{lr}																; Rücksprungadresse zurückholen
		bx		lr																	; zurück zum Linkregister springen
		ENDP
 
;--------------------------------------------
; Unterprogramm: hold
; Aufgabe: Zustand HOLD - Anzeige eingefroren, Zeit läuft im Hintergrund
; Eingabe : R0 = Zeitspanne (Ticks) seit letztem UpdateClk-Aufruf
;--------------------------------------------
hold 	PROC
		push	{lr}																; Rücksprungadresse retten
 
		; --- Zeit weiterzählen (aber nicht anzeigen) ---
		ldr		R1, =TIMEDIFFERENCE													; Adresse der Zeitvariable laden
		ldr		R2, [R1]															; bisherigen Wert laden
		add		R2, R2, R0															; vergangene Ticks (R0) trotzdem dazuzählen
		str		R2, [R1]															; neuen Wert speichern (Anzeige wird hier bewusst NICHT aufgerufen)
 
		; --- LEDs D8 und D9 an ---
		ldr		R1, =GPIO_D_SET														; Adresse des "Einschalten"-Registers laden
		mov		R0, #(LED_D8 :OR: LED_D9)											; Bitmaske für beide LEDs
		strh	R0, [R1]															; beide LEDs einschalten
 
		; --- Taster prüfen: S5 -> INIT, S7 -> RUN ---
		bl		readButtons															; aktuellen Taster-Zustand in R0 lesen
		tst		R0, #button_S5														; Bit 5 (S5) testen
		bne		hold_check_s7														; Bit= 1 -> S5 NICHT gedrückt -> weiter zu S7-Prüfung
		ldr		R1, =STATE															; sonst (S5 gedrückt): Adresse der Zustandsvariable laden
		mov		R2, #STATUS_RUN														; neuer Zustand: INIT
		str		R2, [R1]															; STATE = STATUS_INIT
		b		hold_ende															; fertig
 
hold_check_s7
		tst		R0, #button_S7														; Bit 7 (S7) testen
		bne		hold_ende															; Bit=1 -> S7 NICHT gedrückt -> nichts tun, Ende
		ldr		R1, =STATE															; sonst (S7 gedrückt): Adresse der Zustandsvariable laden
		mov		R2, #STATUS_RUN														; neuer Zustand: RUN
		str		R2, [R1]															; STATE = STATUS_RUN
 
hold_ende
		pop		{lr}																; Rücksprungadresse zurückholen
		bx		lr																	; zurück zum Linkregister springen
		ENDP
 
		ALIGN
		END