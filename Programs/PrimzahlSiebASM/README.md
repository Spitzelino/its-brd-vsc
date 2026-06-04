# ------------------ Probleme ------------------------

- Wir wussten nicht wie wir die Schleife beenden sollten, also haben wir das nur als endfor1: bettietelt. 
- Was auch nen Problem war: Wir wussten am Anfag nicht wie ein Array im Assabler-Code darstellen sollen.
- Einweiteres Problemchen war wie multipülizieren funktioniet aber das war recht einfach zulösen.
- Sonst gab es noch ein Problem mit der Schachtelung des Siebes mit for1 etc., da es viel verschachtelter wurde umso mehr wir hinzugefügt haben.
# ------------------ Aktueller Java-Code -------------

; public class PrimzahlSieb {
;     public static void main(String[] args) {
;         int n = 1000;
;         boolean[] p = new boolean[n + 1];
;                 for (int i = 2; i <= n; i++) p[i] = true;


;                 for (int i = 2; i * i <= n; i++)
;                         if (p[i])
;                              for (int j = i * i; j <= n; j += i)
;                                 p[j] = false;
;     }
; }
# ------------------ Register ------------------------
; Register      Funktion
; R0        =   Basisadresse des Arrays (0x20000000)
; R1        =   n = 1000 (Overgrenze)
; R2        =   i (äußere Schleife)
; R3        =   j (innere Schleife, j = i*i, j+=i)
; R4        =   aktueller Arraywert p[i] oder p[j]
; R5        =   Zähler für gefundene Primzahlen
; R6        =   Konstante 0 zum Schreiben (p[j] = 0)
; R7        =   Hilfregister für das Vielfache (i*i)
# ------------------ Alter Assembler Code ------------

ldr R0, =0x20000000         ; R0 = Basisadresse des Arrays
mov R1, #1000             ; R1 = n=1000 -> obere Grenze

; Initialisierung: p[0] = 0, p[1] = 0, p[2] = 1
    mov R2, #0
    strb R2, [R0, #0]       ; p[0] = 0
    strb R2, [R0, #1]       ; p[1] = 0

for1:                       ; für i=2 bis n=1000 alles als Primzahl betrachtet wird
    mov R4, #1
    strb R4, [R0, R2]       ; p[2] = 1 aber der inhalt von R2 = 0
    mov R2, #2              ; R2 = i = 2 also i = 2 Schleife startet bei 2
until1:
    cmp R2, R1              ; vergleich von i zu n
    bhi for2                ; wenn i > 1000 dann ist Schleife fertig
    mov R4, #1
    strb R4, [R0, R2]       ; p[i] = 1 also könnte eine Primzahl sein
    add R2, R2, #1          ; i++
    b for1                  ; geh wieder zurück zu for1
for2:
    mov R2, #2              ;  R2 = i = 2 (äußere Schleife neustarten)
unitl2:
    cmp R2, R1              ; schauen ob i<=1000 ist
    bhi endfor1             ; wenn i>1000 ist schleife fertig
do2:
    mul R7, R2, R2          ; R7 = i*i (abbruchbedingung der innerren Schleife)
    cmp R7, R1              ; ist i*i <= 1000?
    bhi step1               ; wenn i*i > 1000 dann nicht mehr 7 (Sieben hahahhahaha) ->(alle Vielfachen wurden schon gefunden)
if_1:
    lrdb R4, [R0, R2]       ; R4 = p[i] -> Byte an Adresse R0 + i lesen
    cmp R4, #1              ; ist p[i] == 1 wahr?
    bne step1               ; Wenn p[i] == 0 dann ist i keine Primzahl
for3:
    mul R3, R2, R2          ; R3 = j = i*i (Start der inneren Schleife)
    cmp R3, R1              ; ist j <= 1000?
    bhi step1               ; wenn j > 1000 dann zurück auf die äußere Schleife
do3:
    mov R6, #0              ; R6 = 0 (R6 ist keine Primzahl)
    strb R6, [R0, R3]       ; p[j] = 0 Vielfaches von i wird markiert (gestrichen).
    add R3, R3, R2          ; j += i nächste Vielfaches von i
    b for3                  ; zurück zum Kopf/Anfang/Start der inneren Schleife
step1:
    add R2, R2, #1          ; i++ -> nächste Zahl Prüfen
    b until1                ; zurück zum Kopf der äußeren Schleife
endfor1:                    ; Ende ( das 7 ist fertig)

for_zaehler:
    mov R2, #2              ; R2 = i = 2 (von vorne durchlaufen)
    mov R5, #0              ; R5 = 0 (Zähler beginnt bei null obvie)
until_zaehler:
    cmp R2, R1              ; i <= 1000 ?
    bhi zaehler_fertig      ; wenn i > 1000 dann ist Zähler fertig

    ldrb R4, [R0, R2]       ; R4 = p[i] aktuellen Eintag lesen
    cmp R4, #1              ; p[i] == 1 ? (ist das ne Primzahl?)
    bne zaehler_sprung      ; wenn p[i] == 0 -> dann ist keine Primzahl
    add R5, R5, #1          ; R5++ (R5 + 1) -> Primzahl gefunden yay also counter erhöhen
zaehler_sprung:
    add R2, R2, #1          ; i++ (nächsten eintrag Prüfen)
    b until_zaehler         ; zurück zum SchleifenKopf/Anfang
zaehler_fertig:
    str R5, [R0, #1004]   ; Speicheret die end Anzahl der Primzahlen im Speicher an der Stelle R5