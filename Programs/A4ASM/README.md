# Primzhalen Ermitteln
 
## Das Sieb 
Das Sieb des Eratosthenes welches wir verwenden wollen um die Primzahlen zu ermitteln ist ein vervahren wo man bei der kleinsten Zahl "2" anfäng und dann immer das Vielfache von dieser Zahl bis zur festgelegten Grenze (1000 in der Aufgabe) ermittelt. Diese Vielfachen von der Zahl (Nur Natürliche Zahlen) wird nun gestrichen und als Nicht-Primzahl eingetragen. 

### Aufgabe
Das kann man ja sehr gut als 0(Flase) und 1 (True) darstellen. Man kann also die verschiendene Werte in einem Register speichern. Die größe wird 1001 sein. Also ein Byte größer als die max Anzahl weil wir die zahlen von 0 bis 1000 haben brauchen wir noch ein weiteres Byte für die 1000. 
Das Sieben ist wir betrachten alle Zaheln von "2" bis "1000" erstmal als Primzahl -> filtern/streichen von dem Vielfache von "2" bis "1000"-> zur nächsten Zahl in diesem Fall 3. Das wird in einem Loop gemacht bis zum Ende was in diesem Fall "1000" ist. (Das ist ein Array)

### Java-Code für 7 XD

public class PrimzahlSieb {
    public static void main(String[] args) {
        int n = 1000;
        boolean[] p = new boolean[n + 1]; //Array erstellen

        for (int i = 2; i <= n; i++) p[i] = true; //Alle Zahlen ab 2 werden zuerst als Primzahlen angenommen

        for (int i = 2; i * i <= n; i++)
            if (p[i]) // wenn true wurde die Zahl wurde noch nicht gestrichen -> Primzahl; Wenn false dann ist keine Primzahl
                for (int j = i * i; j <= n; j += i) // das Vielfache wird bestimmt und gestrichen 
                    p[j] = false; //Die Zahl wird gestrichen

        for (int i = 2; i <= n; i++)
            if (p[i]) System.out.println(i); //Ist p[i] == true? Dann ist "i" eine Primzahl obvie wenn es false ist
    }
}