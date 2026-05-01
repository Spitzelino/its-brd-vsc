;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Martin Becke    
;* Version            : V1.0
;* Date               : 01.06.2021
;* Description        : This is a simple main to demonstrate data transfer
;                     : and manipulation.
;                     : 
;
;*******************************************************************************
    EXTERN initITSboard ; Helper to organize the setup of the board

    EXPORT main         ; 

ConstByteA  EQU 0xaffe
    
;* We need some data to work on
    AREA DATA, DATA, align=2    
VariableA   DCW 0xbeef
VariableB   DCW 0x1234
VariableC   DCW 0xaffe

;* We need minimal memory setup of InRootSection placed in Code Section 
    AREA  |.text|, CODE, READONLY, ALIGN = 3    
    ALIGN   
main
    BL initITSboard             ; needed by the board to setup
;* swap memory - Is there another, at least optimized approach?
    ldr     R0,=VariableA   ; Anw01
    ldrb    R2,[R0]         ; Anw02
    ldrb    R3,[R0,#1]      ; Anw03
    lsl     R2, #8          ; Anw04
    orr     R2, R3          ; Anw05
    strh    R2,[R0]         ; Anw06 
    
;* const in var
    mov     R5,#ConstByteA  ; Anw07
    strh    R5,[R0]         ; Anw08

;* Eigene Erweiterung für VariableC
    ldr     R0, =VariableC  ; Lade die Adresse der neuen VariableC in R0
    ldrb    R2, [R0]        ; Lade das "niederwertige" Byte 0xFE in R2
    ldrb    R3, [R0, #1]    ; Lade das "hochwertige" Byte 0xAF in R3
    lsl     R2, #8          ; Schiebe 0xAF acht Stellen nach links -> 0xAF00
    orr     R2, R3          ; Verknüpfe es mit 0xFE -> R2 enthält jetzt 0xAFFE
    strh    R2, [R0]        ; Speicher das Ergebnis an die Adresse von VariableC

;* Andere Version für VariableC     
    ;ldr     R0, =VariableC  ; Lade die Adresse der neuen VariableC in R0
    ;mov     R2, #0xAF       ; Lade das "hochwertige" Byte 0xAF in R2
    ;strb    R2, [R0]        ; Speichere AF an die erste Adresse (links)
    ;mov     R3, #0xFE       ; Lade das "niederwertige" Byte 0xFE in R3
    ;strb    R3, [R0, #1]    ; Speichere 0xFE (rechts daneben)    

;* Change value from x1234 to x4321
    ldr     R1,=VariableB   ; Anw09
    ldrh    R6,[R1]         ; Anw0A
    ;mov     R7, #0x30ED     ; Anw0B
    ;add     R6, R6, R7      ; Anw0C

    mov     R6, #0x3412      ; Laden den Wert direkt "verdreht"

    strh    R6,[R1]         ; Anw0D
    b .                     ; Anw0E
    
    ALIGN
    END