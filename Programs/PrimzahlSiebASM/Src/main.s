;________________________________________________
; 				Java Code
;________________________________________________

;public class PrimzahlSieb {
;    public static void main(String[] args) {
;       int n = 1000;
;        boolean[] p = new boolean[n + 1]; //Array erstellen
;
;        for (int i = 2; i <= n; i++) p[i] = true; //Alle Zahlen ab 2 werden zuerst als Primzahlen angenommen
;
;        for (int i = 2; i * i <= n; i++)
;            if (p[i]) // wenn true wurde die Zahl wurde noch nicht gestrichen -> Primzahl; Wenn false dann ist keine Primzahl
;                for (int j = i * i; j <= n; j += i) // das Vielfache wird bestimmt und gestrichen 
;                    p[j] = false; //Die Zahl wird gestrichen
;
;        for (int i = 2; i <= n; i++)
;            if (p[i]) System.out.println(i); //Ist p[i] == true? Dann ist "i" eine Primzahl obvie wenn es false ist
;    }
;}

;________________________________________________
; 			Speicher Darstellung
;________________________________________________

;NatZahl :   0   1   2   3   4   5   6   7   8   9  10  11  12  13  ...  1000
;        -------------------------------------------------------------------
;primZahl:  [0] [0] [1] [1] [0] [1] [0] [1] [0] [0] [0] [1] [0] [1] ...  [?]

;________________________________________________
;			Assambler Pseudo Code/Planung
;________________________________________________

; Wenn von true gesprochen wird ist das im Speicher eine 1 -> false=0, true=1
;------------ Was soll passieren? ---------------
; Wie im java Code beschrieben kann man True und False haben also brauchen wir 2 Register im RAM
; Das erste Register für NatZahl: Welches 2002 Byte groß ist und die Zahlen 0-1000 beinhaltet wobei jede Zahl zwei Byte zu geschrieben wird. (weil ein Byte nur bis 255 geht)
; Das zweite Register für Primzahl: welches die Echten-Primzahlen welche schon erkannt wurden eintägt. Jede Primzahl wird als 2 Byte gespeichert
;------------------------------------------------

;------------ Register was ist das? -------------
; r0 für NatZahl ( p[] (boolean[] p = new boolean[n + 1]) )
; r1 für 1000 (n=1000)
; r2 fäng bei 2 an ist im Java Code das "i" also prüfung ob Primzahl 
; r3 also das "j" im Java Code welches das Vielfache von "i" markiert (j=i*i)
; r4 Register des aktuellen Arraywert p[i]
; r5 (optional) Zähler für gefundene Primzahlen (im Java-Code nicht vorhanden, nur für Ausgabe)
; r6 p[j]
; r7 für multipikation funktion mul
;------------------------------------------------

;-------- Hmm jetzt wird es spannend ------------
; Zu Beginn wird ein boolean-Array erstellt, in dem jede Zahl zunächst als potenzielle Primzahl gilt:
; - n ist fest auf 1000 gesetzt (obere Grenze).
; - Array p[] wird mit Größe n + 1 angelegt.
; - Schleife läuft von Index 2 bis Index 1000.
; - Jeder Eintrag p[i] wird auf true gesetzt (true = mögliche Primzahl).
; - Die Indizes 0 und 1 bleiben false, da 0 und 1 per Definition keine Primzahlen sind.

;---------------- Hauptlogik 7 ------------------

; - Äußere Schleife: i läuft von 2 bis n.
; - Bedingung: i * i <= n (nur bis zur Wurzel von n prüfen, da größere Faktoren bereits abgedeckt sind).
; -Lade p[i] aus dem Array

; - Wenn p[i] == false:
; 	-> Zahl wurde bereits gestrichen, also keine Primzahl.
;  			-> Überspringe diesen Wert und gehe zu i + 1.
; - Wenn p[i] == true:
; 	-> i ist eine Primzahl.
; 			-> Starte innere Schleife zum Streichen der Vielfachen.
; 			 - INNERE SCHLEIFE (Vielfache streichen):
; 			 - Startwert: j = i * i (Optimierung, kleinere Vielfache sind bereits entfernt).
; 			 - Bedingung: solange j <= n gilt.
; 			 - Aktion: setze p[j] = false (Zahl ist keine Primzahl mehr).
;			 - Schritt: erhöhe j um i (j = j + i), um das nächste Vielfache zu erreichen.

; - Wiederhole diesen Vorgang, bis j > n.

; ----------- AUSGABE DER PRIMZAHLEN --------------
; Nach Abschluss des Sieb-Algorithmus werden alle verbleibenden Primzahlen ausgegeben.
; - Schleife läuft erneut von Index 2 bis Index 1000.
; - Lade p[i] aus dem Array.

; - Wenn p[i] == true:
; 	-> i ist eine Primzahl.
; 		-> Ausgabe erfolgt (wie System.out.println(i).)

; - Wenn p[i] == false:
; 	-> keine Aktion, Zahl wird ignoriert.
; 		-> Wiederholung bis i = 1000 erreicht ist.



; public class PrimzahlSieb {
;     public static void main(String[] args) {
;         int n = 1000;
;         boolean[] p = new boolean[n + 1];
;                 for (int i = 2; i <= n; i++) p[i] = true;
;                      for (int i = 2; i * i <= n; i++)
;                         if (p[i])
;                              for (int j = i * i; j <= n; j += i)
;                                 p[j] = false;
;     }
; }
;------------ Register was ist das? -------------
; R0  = Basisadresse des Arrays (0x20000000)
; R1  = n = 1000
; R2  = i (äußere Schleife)
; R3  = j (innere Schleife, j = i*i, j+=i)
; R4  = aktueller Arraywert p[i] oder p[j]
; R5  = Zähler für gefundene Primzahlen
; R6  = Konstante 0 zum Schreiben (p[j] = 0)
; R7  = Hilfregister für i*i
;________________________________________________

;________________________________________________
;		       	Assambler Code
;________________________________________________
            AREA MyData, DATA, align = 2
Basis DCD 0







    AREA |.text|, CODE, READONLY, ALIGN = 3
    EXPORT main
main PROC

    ldr R0, =Basis 
    mov R1, #1000      
; Initialisierung: p[0] = 0, p[1] = 0, p[2] = 1
    mov R2, #0
    strb R2, [R0, #0]       ; p[0] = 0
    strb R2, [R0, #1]       ; p[1] = 0
for1                        ; für i=2 bis n=1000 alles als Primzahl betrachtet wird
    mov R4, #1
    strb R4, [R0, R2]       ; p[2] = 1 aber der inhalt von R2 = 0
    mov R2, #2              ; R2 = i = 2 also i = 2 Schleife startet bei 2
until1
    cmp R2, R1              ; vergleich von i zu n
    bhi for2                ; wenn i > 1000 dann ist Schleife fertig
    mov R4, #1
    strb R4, [R0, R2]       ; p[i] = 1 also könnte eine Primzahl sein
    add R2, R2, #1          ; i++
    b for1                  ; geh wieder zurück zu for1
for2
    mov R2, #2              ;  R2 = i = 2 (äußere Schleife neustarten)
unitl2
    cmp R2, R1              ; schauen ob i<=1000 ist
    bhi endfor1             ; wenn i>1000 ist schleife fertig
do2
    mul R7, R2, R2          ; R7 = i*i (abbruchbedingung der innerren Schleife)
    cmp R7, R1              ; ist i*i <= 1000?
    bhi step1               ; wenn i*i > 1000 dann nicht mehr 7 (Sieben hahahhahaha) ->(alle Vielfachen wurden schon gefunden)
if1
    ldrb R4, [R0, R2]       ; R4 = p[i] -> Byte an Adresse R0 + i lesen
    cmp R4, #1              ; ist p[i] == 1 wahr?
    bne step1               ; Wenn p[i] == 0 dann ist i keine Primzahl
for3
    mul R3, R2, R2          ; R3 = j = i*i (Start der inneren Schleife)
    cmp R3, R1              ; ist j <= 1000?
    bhi step1               ; wenn j > 1000 dann zurück auf die äußere Schleife
do3
    mov R6, #0              ; R6 = 0 (R6 ist keine Primzahl)
    strb R6, [R0, R3]       ; p[j] = 0 Vielfaches von i wird markiert (gestrichen).
    add R3, R3, R2          ; j += i nächste Vielfaches von i
    b for3                  ; zurück zum Kopf/Anfang/Start der inneren Schleife
step1
    add R2, R2, #1          ; i++ -> nächste Zahl Prüfen
    b until1                ; zurück zum Kopf der äußeren Schleife
endfor1                    ; Ende ( das 7 ist fertig)

for_zaehler
    mov R2, #2              ; R2 = i = 2 (von vorne durchlaufen)
    mov R5, #0              ; R5 = 0 (Zähler beginnt bei null obvie)
until_zaehler
    cmp R2, R1              ; i <= 1000 ?
    bhi zaehler_fertig      ; wenn i > 1000 dann ist Zähler fertig

    ldrb R4, [R0, R2]       ; R4 = p[i] aktuellen Eintag lesen
    cmp R4, #1              ; p[i] == 1 ? (ist das ne Primzahl?)
    bne zaehler_sprung      ; wenn p[i] == 0 -> dann ist keine Primzahl
    add R5, R5, #1          ; R5++ (R5 + 1) -> Primzahl gefunden yay also counter erhöhen
zaehler_sprung
    add R2, R2, #1          ; i++ (nächsten eintrag Prüfen)
    b until_zaehler         ; zurück zum SchleifenKopf/Anfang
zaehler_fertig
    str R5, [R0,#1004]   ; Speicheret die end Anzahl der Primzahlen im Speicher an der Stelle R5





forever	b	forever		; nowhere to retun if main ends		
		ENDP
	
		ALIGN
       
		END
