# Stoppuhr - GTP Praktikum, HAW Hamburg
    
    Aufgabe:    
    Assembler-Stoppuhr mit TFT-Display, Tastern und LEDS


    Ziel:       
    Programmierung einer Stoppuhr auf dem ITS-Board in ARM-Assembler. Die Zeit wird im Format mm:ss:nn auf dem TFT-Display angezeigt mit einer Auflösung von 1/100 von Sekunden. Die Steurung erfolgt über drei Taster (S5, S6 & S7) und der Betriebszustand wird über zwei LEDs (D8, D9) visualisiert. 


    Zustandautomaten:

              S7             S6
       INIT ------> RUN <----------> HOLD
        ^            |                |
        |            |                |
        +---- S5 ----+------ S5 ------+

        Zustand    |    D8    |     D9     |     Beschreibung    
    ---------------|----------|------------|----------------------------------------------------------------------------------------------
         INIT      |   aus    |    aus     |     Zeit auf 00:00:00 gesetzt
         RUN       |   an     |    aus     |     Zeit läuft und Display wird aktualierst   
         HOLD      |   an     |    an      |     Anzeige stoppt, aber im Hintergrund wird weiter gezählt

    Assembler - Unterprogamm: 


