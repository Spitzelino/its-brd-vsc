# Stoppuhr - GTP Praktikum, HAW Hamburg
    
    Aufgabe:    
    Assembler-Stoppuhr mit TFT-Display, Tastern und LEDS


    Ziel:       
    Programmierung einer Stoppuhr auf dem ITS-Board in ARM-Assembler. Die Zeit wird im Format mm:ss.nn auf dem TFT-Display angezeigt mit einer Auflösung von 1/100 von Sekunden. Die Steurung erfolgt über drei Taster (S5, S6 & S7) und der Betriebszustand wird über zwei LEDs (D8, D9) visualisiert. 


    Zustandautomaten:

              S7             S6
       INIT ------> RUN <----------> HOLD
        ^            |                |
        |            |                |
        +---- S5 ----+------ S5 ------+

        Zustand    |    D8    |     D9     |     Beschreibung    
    ----------------------------------------------------------------------------------------------
         INIT      |   aus    |    aus     |     Zeit auf 00:00.00 gesetzt
         RUN       |   an     |    aus     |     Zeit läuft und Display wird aktualierst   
         HOLD      |   an     |    an      |     Anzeige stoppt, aber im Hintergrund wird weiter gezählt

    Assembler - Unterprogamm: 

        Funktion           |         Ausgabe                       
    ---------------------------------------------------------------------------------------------------------------
        initDisplay        |         Titel und Startzeit auf TFT ausgeben
        readButtons        |         GPIO_F_PIN lesen, Rückgabe in R0 (Bit=0 → gedrückt)
        displayZeit        |         Zeitwert (Ticks) in mm:ss.nn umrechnen und auf TFT ausgeben
        UpdateClk          |         TIMER lesen, Zeitspanne seit letztem Aufruf in R0 zurückgeben
        init               |         Zeit auf 0, Anzeige zurücksetzen, LEDs aus, Taster -> RUN
        run                |         Zeit aufaddieren, Anzeige aktualisieren, LED D8 an, Taster -> HOLD/INIT
        hold               |         Zeit weiter aufaddieren (Anzeige steht), LED D8+D9 an, Taster -> INIT/RUN

    Zeitumrechnung (displayZeit):

        Berechnung beginnt mit der größten Einheit (10 Minuten) und arbeitet sich
        per Division + Rest zu den kleineren Einheiten durch:
        10min (60 000 000 Ticks) -> 1min (6 000 000) -> 10s (1 000 000) -> 1s (100 000) -> Rest = Hundertstel.
    