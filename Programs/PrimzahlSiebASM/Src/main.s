;************************************************
;* GTP - Grundlagen der Technischen Informatik  *
;* Aufgabe 4 / 5 / 6: PrimzahlSieb              *  
;*                                              *
;* Team:                                        *
;*   Xuan Hoang Duy Trinh Matrikel-Nr. 2881544  *
;*   Jan Klindtworth      Matrikel-Nr. 2884053  *
;************************************************


;------------------------------------------------
;		       	Registerzuweisung
;------------------------------------------------


                AREA MyData, DATA, align = 2
Grenze       EQU    0x3E8                                   ; Definiert die Obergrenze des Suchbereichs auf den Wert 1000
Basis        FILL   Grenze + 1                              ; Reserviert Speicherplatz für das Sieb-Feld (1 Byte pro Zahl von 0 bis 1000)
Prim         FILL   0x3BC                                   ; Reserviert Speicherplatz für gefundene Primzahlen (956 Bytes für max. 239 Zahlen)
    AREA |.text|, CODE, READONLY, ALIGN = 3
        		EXPORT main
        		EXTERN initITSboard
main            PROC

;------------------------------------------------
;		       	Assambler Code
;------------------------------------------------

    
            ldr     R0,=Basis                               ; Lädt die Startadresse von Basis in das Register R0
            ldr     R1,=Grenze                              ; Lädt die Obergrenze (1000) in das Register R1 
for_init

            mov     R2, #2                                  ; Kopiert den Startwert 2 in das Register R2 (erste Primzahl) 
            mov     R4, #1                                  ; Kopiert den Wert 1 (= "ist Primzahl") in das Register R4

until_init

            cmp     R2, R1                                  ; Vergleicht R2 mit R1
            bhi     end_init                                ; Springt zum Ende, falls i > 1000

do_init

            strb    R4, [R0, R2]                            ; Speichert ein niederwertiges Byte aus R4 (aktueller Arraywert)in die Adresse R0 mit einem Offset von R2

step_init 

            add     R2, #1                                  ; Erhöht R2 um 1 (nächste Zahl) 
            b       until_init                              ; Springt zurück zum Schleifenanfang

end_init

;------------------------------------------------
;               äußere Schleife
;------------------------------------------------

for_7

            mov     R2, #1                                  ; Kopiert den Startwert 1 in R2
            mov     R6, #0                                  ; Kopiert den Löschwert 0 in R6

untilfor_7

            mul     R7, R2, R2                              ; Multipliziert i * i und speichert in R7 (Hilfsregister)
            mov     R3, R7                                  ; Schiebt das Vielfache in R3 = j 
            cmp     R3, R1                                  ; Vergleicht R3 mit R1
            bhi     endfor_7                                ; Springt zum Abspeichern, falls j= i * i > 1000

dofor_7

            ldrb    R4, [R0,R2]                             ; Liest ein Byte aus der Adresse R0 mit einem Offset von R2 und speichert es in R4
            b       if_7                                    ; Springt zur Primzahl-Prüfung 

stepfor_7

            b       naechster                               ; Springt zum nächsten Schritt 

endfor_7

            b       abspeichern                             ; Springt zur Teilfunktion Abspeichern


if_7

            cmp     R4, #1                                  ; Vergleicht R4 (aktueller Arraywert) mit der Konstanten 1
            beq     thenif_7                                ; Springt zum Löschen, falls R4 == 1
            b       endif_7                                 ; Springt weiter, falls R4 == 0 (bereits gelöscht)

thenif_7

            b       for_streichen                           ; Springt in die innere Schleife zum Löschen

endif_7

            b       naechster                               ; Springt zum nächsten Schleifendurchlauf


;------------------------------------------------
;               innere Schleife
;------------------------------------------------


for_streichen

until_streichen

            cmp     R3, R1                                  ; Vergleicht R3 mit R1
            bhi     endfor_streichen                        ; Springt zum Ende der inneren Schleife, falls j > 1000 

dofor_streichen

            strb    R6, [R0, R3]                            ; Speichert ein niederwertiges Byte aus R6 (p[j] = 0) in die Adresse R0 mit einem Offset von R3


stepfor_streichen

            add     R3, R2                                  ; Erhöht R3 um R2 für nächstes Vielfaches (j+ = i)
            b       until_streichen                         ; Springt zurück zur inneren Schleifenkopf

endfor_streichen   

            b       naechster                               ; Springt zum nächsten Schleifendurchlauf   


;------------------------------------------------
;                   quasi ++i
;------------------------------------------------


naechster

            add     R2, #1                                  ; Erhöht R2 um 1 (nächste Zahl) 
            b       untilfor_7                              ; Springt zurück zur Prüfung der äußeren Schleife


;------------------------------------------------
;                  Abspeichern
;------------------------------------------------


abspeichern

            ldr     R5, =Prim                               ; Lädt Startadresse von Prim in R5 (Zähler für gefundene Primzahlen)

for_abspeichern

            mov     R2, #2                                  ; Kopiert die Konstante 2 in R2

untilfor_abspeichern

            cmp     R2, R1                                  ; Vergleicht R2 mit R1
            bhi     endfor_abspeichern                      ; Springt zum Ende, falls i > 1000
        
dofor_abspeichern

            ldrb    R4, [R0, R2]                            ; Liest ein Byte aus der Adresse R0 mit einem Offset von R2 und speichert es in R4
            b       if_abspeichern                          ; Springt zum Abspeichern  
    
stepfor_abspeichern

endfor_abspeichern

            b       forever                                 ; Springt in die Endlosschleife (Programmende)

if_abspeichern

            cmp     R4, #1                                  ; Vergleicht R4 mit 1
            beq     thenif_abspeichern                      ; Springt zum Speichern, falls R4 == 1
            b       endif_abspeichern                       ; Springt weiter zum Ende des Speichervorganges 

thenif_abspeichern

            str     R2, [R5]                                ; Schreibt die Primzahl R2 als 32-Bit-Wert an Adresse in R5
            add     R5, #4                                  ; Erhöht die Zieladresse R5 um 4 Bytes (R5 = R5 + 4)       
            b       endif_abspeichern                       ; Springt weiter zum Ende des Speichervorganges 

endif_abspeichern

            add     R2, #1                                  ; Erhöht R2 um 1 (nächste Zahl)    
            b       untilfor_abspeichern                    ; Springt zurück zur Schleifenprüfung der Abspeicherung



forever	b	forever		; nowhere to retun if main ends		; Verbleibt in Endlosschleife
		ENDP
	
		ALIGN
       
		END
