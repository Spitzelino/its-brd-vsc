;************************************************
; GT - Grundlagen der Technischen Informatik
; Aufgabe 4-5-6: PrimzahlSieb
;
; Team:
;   Xuan Hoang Duy Trinh Matrikel-Nr. 2881544
;   Jan Klindtworth      Matrikel-Nr. 2884053
;************************************************


;------------------------------------------------
;		       	Rigister Zuweise
;------------------------------------------------


                AREA MyData, DATA, align = 2
Grenze       EQU    0x3E8
Basis        FILL   Grenze + 1
Prim         FILL   0x7D0

    AREA |.text|, CODE, READONLY, ALIGN = 3
        		EXPORT main
        		EXTERN initITSboard

main            PROC


;------------------------------------------------
;		       	Assambler Code
;------------------------------------------------

    
            ldr     R0,=Basis
            ldr     R1,=Grenze
for_init

            mov     R2, #2
            mov     R4, #1

until_init

            cmp     R2, R1
            bhi     end_init

do_init

            strb    R4, [R0, R2]

step_init 

            add     R2, #1
            b       until_init

end_init

;------------------------------------------------
;               äußere Schleife
;------------------------------------------------

for_7

            mov     R2, #1
            mov     R6, #0

untilfor_7

            mul     R7, R2, R2
            mov     R3, R7
            cmp     R3, R1
            bhi     endfor_7

dofor_7

            ldrb    R4, [R0,R2]
            b       if_7

stepfor_7

            b       naechster

endfor_7

            b       abspeichern


if_7

            cmp     R4, #1
            beq     thenif_7
            b       endif_7

thenif_7

            b       for_streichen

endif_7

            b       naechster


;------------------------------------------------
;               innere Schleife
;------------------------------------------------


for_streichen

until_streichen

            cmp     R3, R1
            bhi     endfor_streichen

dofor_streichen

            strb    R6, [R0, R3]

stepfor_streichen

            add     R3, R2
            b       until_streichen

endfor_streichen   

            b       naechster


;------------------------------------------------
;                   quasi ++i
;------------------------------------------------


naechster

            add     R2, #1
            b       untilfor_7


;------------------------------------------------
;                  Abspeichern
;------------------------------------------------


abspeichern

            ldr     R5, =Prim

for_abspeichern

            mov     R2, #2

untilfor_abspeichern

            cmp     R2, R1
            bhi     endfor_abspeichern
        
dofor_abspeichern

            ldrb    R4, [R0, R2]
            b       if_abspeichern
    
stepfor_abspeichern

endfor_abspeichern

            b       forever

if_abspeichern

            cmp     R4, #1
            beq     thenif_abspeichern
            b       endif_abspeichern

thenif_abspeichern

            str     R2, [R5]
            add     R5, #4
            b       endif_abspeichern

endif_abspeichern

            add     R2, #1
            b       untilfor_abspeichern



forever	b	forever		; nowhere to retun if main ends		
		ENDP
	
		ALIGN
       
		END
