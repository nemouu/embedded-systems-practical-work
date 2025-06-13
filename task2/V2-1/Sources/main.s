/************************************************************
Versuch: 2-1
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 16 Stunden
************************************************************/

/*
Antwort zu Aufgabenteilen:


Aufgabenteil (a).
Zunaechst ist zu erwaehnen, dass die Matrix M als Array zeilenweise gespeichert
wurde. Das heisst das Array im Speicher beginnt mit den Elementen der ersten 
Zeile der Reihe nach und darauf folgen die Elemente der zweiten Zeile der Reihe
nach und so weiter. 
Die Matrix N wurde auch als Array gespeichert aber es wurde hierbei spaltenweise
vorgegangen, da dies fuer die auszufuehrenden Multiplikationen und Additionen
besser auskommt. Das heisst im Array fuer N stehen erst die Elemente der ersten
Spalte der Reihe nach und darauf folgen dann die Elemente der zweiten Spalte
wieder der Reihe nach und so weiter.

Bei der Multiplikation quadratischer Matrizen gibt es fuer jeden Eintrag
so viele Multiplikationen wie es Zeilen bzw. Spalten gibt. Das heisst in 
dem Fall dieser Aufgabe haben wir 4 Multiplikationen pro Matrixeintrag, das
heisst also insgesamt 4*16 = 64 Multiplikationen und entsprechend viele
Befehle.

Mit dem DSP Befehl smlad konnten hingegen immer zwei dieser Multiplikationen
in einem Befehl erledigt werden und deshalb wurden nur fuer die Multiplikationen
in diesem Fall nur 32 Befehle ausgefuehrt. Zusaetzlich dazu ergeben sich auch
durch die Additionen noch Effizienzvorteile. 


Aufgabenteil(d). 
Es folgen die Berechnungen und Interpretationen für die in der 
Aufgabenstellung angegebenen Befehle. Dazu gehen wir die einzelnen Ergebnisse
(siehe Terminal) und die bei jedem Befehl (ggf.) gesetzten Bits durch und
interpretieren diese entsprechend. Alle diese Instruktionen bearbeiten eine
Addition halbwortweise, das heisst es wird immer das erste Halbwort des ersten
Registers zu dem ersten Halbwort des zweiten Registers addiert. Entsprechendes
wird dann mit dem zweiten Halbwort der beiden Eingaberegister gemacht.

UADD16 - GE setting dual 16-bit unsigned addition
	   Hierbei geben uns die GE flags Auskunft darüber, ob ein Overflow aufgetreten ist
	   
(A,B):  1.HW: a436 + 10a7 = b4dd und 2.HW: 7c7b + 8933 = 105ae
 	   -> In der zweiten Addition tritt ein Overflow auf und dies wird durch
 	  	  die GE Flags angezeigt (0011 in diesem Fall).
 	  	  
(A,C): 1.HW: a436 + c553 = 16989 und 2.HW: 7c7b + 5f2c = dba7
	   -> In der ersten Addition tritt ein Overflow auf und dies wird durch
 	  	  die GE Flags angezeigt (1100 in diesem Fall).
 	  	  
(A,D): 1.HW: a436 + 788e = 11cc4 und 2.HW: 7c7b + 84b1 = 1012c
	   -> In beiden Additionen tritt ein Overflow auf und dies wird durch
 	  	  die GE Flags angezeigt (1111 in diesem Fall).


SADD16 - GE setting dual 16-bit signed addition
	   Hierbei geben uns die GE flags Auskunft darüber, ob das jeweilige Ergebnis groesser 
	   oder kleiner 0 ist. Das heisst wir muessen die Rechnungen ueberpruefen und schauen, 
	   ob ein Overflow passiert.
	   
(A,B):  1.HW: a436 + 10a7 = b4dd und 2.HW: 7c7b + 8933 = 05ae
 	   -> Hier tritt kein Overflow auf!
 	  	  
(A,C):  1.HW: a436 + c553 = ffff6989 und 2.HW: 7c7b + 5f2c = 0000dba7
	   -> In beiden Additionen tritt ein Overflow auf. Dies passiert, da in beiden Faellen
	   der darstellbare Bereich (-2^15 bis 2^15 - 1) verlassen wird. Das erste HW ist kleiner
	   als der kleinst moegliche negative Wert und das zweite HW ist groesser als der groesst
	   moegliche positive Wert.
 	  	  
(A,D):  1.HW: a436 + 788e = 1cc4 und 2.HW: 7c7b + 84b1 = 012c
 	   -> Hier tritt kein Overflow auf!


UQADD16 - Dual 16-bit unsigned saturating addition
		Hierbei wird genau wie bei UADD16 eine unsigned Addition durchgefuehrt aber jetzt 
		werden die Ergebnisse der einzelnen Additionen immer auf 16 Bit (Zahl zwischen 
		0 und 2^16 - 1)saturiert, wenn ein Overflow auftritt. Entsprechend werden die 
		Halbwörter, die unter UADD16 einen Overflow erzeugt haben hier nun saturiert 
		(vgl. die HW im Terminal mit ffff).


QADD16 - Dual 16-bit saturating addition
		Hierbei wird genau wie bei UADD16 eine unsigned Addition durchgefuehrt aber jetzt 
		werden die Ergebnisse der einzelnen Additionen immer auf 16 Bit (hier eine Zahl 
		zwischen -2^15 und 2^15 - 1) saturiert, wenn ein Overflow vorliegt. Entsprechend 
		wird das erste HW im Ergebnis von QADD16(A,C) zur kleinsten moeglichen Zahl saturiert 
		(8000 = -2^15) und das zweite HW in demselben Ergebnis wird zur groessten moeglichen 
		Zahl saturiert (7fff = 2^15 - 1). Andere Ergebnisse werden nichtsaturiert, da bei der 
		signed Addition ansonsten kein Overflow auftritt (vgl. mit Ergebnissen aus den 
		Berechnungen zu SADD16).
		
		
Aufgabenteil (e)
Um das hier geforderte umzusetzen können die Befehle usat16 (unsigned Saturation) 
und ssat16 (signed saturation) genutzt werden. 

USAT16(A) und USAT16(B) - Halfword-wise unsigned saturation to any bit position
		Bei dieser Instruktion ist zu beobachten, dass die Eingabe als signed value 
		interpretiert wird. Das heisst alle HW, die "groesser" als 0x7fff sind, werden
		als negative Zahlen gewertet (fuehrende 1) und entsprechend zu der naechst
		groesseren Zahl im erlaubten Bereich (0 bis 2^13) saturiert, also der 0x0000.
		Alle Eingabewerte "kleiner oder gleich" 0x7fff hingegen werden als positive 
		Zahl interpretiert (fuehrende 0) und deshalb auf die naechst kleinere Zahl
		im erlaubten Zahlenbereich saturiert, also die 0x1fff. Dies passiert natuerlich
		nur, wenn sie gleich 0x7fff sind oder zwischen 0x7fff und 0x1fff liegen. 
		Entsprechend verhalten sich die Ergebnisse fuer USAT16(A) und USAT16(B), 
		hierbei ist nur zu beachten, dass das erste HW von B von vornherein im erlaubten 
		Bereich liegt und deshalb wird hier nicht saturiert.

SSAT16(A) und SSAT16 - Halfword-wise signed saturation to any bit position
		Hier ist das prinzipielle Vorgehen wie bei der vorherigen Instruktion. Der 
		Unterschied ist nun, dass wegen des Vorzeichens der kleinst moegliche Wert
		0xf000 ist und der groesst moegliche Wert 0x0fff. Dies liegt daran, dass
		der zulässige Bereich nun von -2^12 bis 2^12 - 1 geht. Das ist auch der 
		Grund fuer die Saturation des ersten HW von B bei dieser Instruktion, denn
		0x10a7 liegt nun nicht mehr in dem erlaubten Bereich und wird damit auch
		auf den naechst kleineren Wert aus dem erlaubten Bereich saturiert (0x0fff).
		Es bleibt zu erwaehnen, dass der kleinste Wert 0xf000 ist und nicht wie 
		vielleicht erwartet 0x1000. Hierbei wird davon ausgegangen, dass es sich um
		Vorzeichenerweiterung handelt.
*/

// Include-Dateien
.include "k1514.inc"			// Praktikumsspezifische Definitionen
.include "lib_pit.inc"			// Einfache Unterprogramme zur Zeitmessung
.include "lib_uart.inc"			// Unterprogramme zur Ein-/Ausgabe vom/zum Terminal (CuteCom)

// Assemblerdirektiven
.text							// hier beginnt ein Code-Segment
.align	2						// Ausrichtung an eine gerade Adresse
.global	main					// "main" wird als globales Symbol deklariert
.syntax unified

// Konstanten
.EQU COUNTER_INNEN, 0x2			// Zaehler fuer Anzahl der Durchlaeufe in einer Spalte
.EQU COUNTER_AUSSEN, 0x4		// Zaehler Anzahl von Spalten und Zeilen
.EQU COUNTER_PRODUCT, 0x8		// Zaehler fuer die Berechnung der Produkt-Summe
.EQU VALUE_A, 0xa4367c7b		// Wert fuer A wie in der Aufgabenstellung
.EQU VALUE_B, 0x10a78933		// Wert fuer B wie in der Aufgabenstellung
.EQU VALUE_C, 0xc5535f2c		// Wert fuer C wie in der Aufgabenstellung
.EQU VALUE_D, 0x788e84b1		// Wert fuer D wie in der Aufgabenstellung
.EQU NEW_LINE, 0x0a				// Konstante fuer die neue Zeile (Ascii-Code)
.EQU SPACE, 0x20				// Konstante fuer das Leerzeichen (Ascii-Code)
.EQU SAT_BIT, 0xd				// Konstante fuer Bit fuer das saturiert werden soll (Teil (e))
.EQU OFFSET_INIT, 0x0			// Konstante fuer initialen Offset Wert

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init

/*
Aufgabenteil (a).
Hier wird die in der Aufgabenstellung gegebene Matrixmultiplikation
durchgefuehrt. Zunaechst werden die Adressen und einige Counter 
initialisiert und danach startet die Berechnung. Hierbei wird jede
Zeile der Matrix M mit jeder Spalte der Matrix N multiplizert und
anschliessend das Ergebnis an entsprechender Stelle gespeichert. Es
wird mit der ersten Zeile von M begonnen, so, dass zuerst die erste
Zeile der Ergebnismatrix berechnet wird. Dann wird dies in der zweiten 
Zeile von M fortgesetzt und so weiter. Anschliessend wird das Ergebnis
aus das Terminal ausgegeben.
*/

    ldr r0, =matrix_M					// Lade Adresse der Matrix M			    
    ldr r1, =matrix_N   				// Lade Adresse der Matrix N
    ldr r2, =result						// Lade Adresse der Ergebnismatrix
       		 
    mov r3, #COUNTER_AUSSEN				// Counter fuer die Anzahl der Zeilen von M 		
    mov r4, #OFFSET_INIT				// und fuer den Offset der aktuellen Zeile
    
matrix_loop_zeilen:						// Loop der alle Zeilen von M durchgeht
    mov r5, #OFFSET_INIT          		// Counter fuer die Anzahl der Spalten von N
    mov r6, #COUNTER_AUSSEN				// und fuer den Offset der aktuellen Spalte 
    
matrix_loop_spalten:					// Loop der alle Spalten von N durchgeht
    mov r7, #OFFSET_INIT          		// Setze der Register zurueck in das das Ergebnis geschrieben werden soll
    mov r8, r4          				// Counter fuer die aktuelle Zeile von M (mit Offset) 
    mov r9, #COUNTER_INNEN				// und fuer die Anzahl der Elemente der aktuellen Spalte
    
matrix_loop_akt_spalte:					// Loop der die aktuelle Spalte mit der aktuellen Zeilen verarbeitet   
    ldr r10, [r0, r8]					// Lade aktuelle Adressen der   			
    ldr r11, [r1, r5]   				// aktuellen Werte mit Offset
    smlad r7, r10, r11, r7				// Berechnung des Ergebnisses        
    add r8, r8, #4						// Inkrementiere die Offsets
    add r5, r5, #4           			// der beiden Adressen
  
    subs r9, r9, #1						// Wurde diese Spalte komplett bearbeitet?                   
    bne matrix_loop_akt_spalte			// Wenn nicht springe zurueck!
    
    str r7, [r2], #4					// Speichere Ergebnis an entsprechender Stelle und inkrementiere Adresse				  
    
    subs r6, r6, #1						// Wurde diese Zeile komplett bearbeitet?
    bne matrix_loop_spalten				// Wenn nicht springe zurueck!
    
    add r4, r4, #8						// Inkrementiere Counter fuer die Zeilen von M so, dass die naechste Zeile addressiert wird
    
    subs r3, r3, #1						// Wurden alle Zeilen der Matrizen bearbeitet?
    bne matrix_loop_zeilen				// Wenn nicht springe zurueck!
  
/*
Hier beginnt die Ausgabe des Ergebnisses auf das Terminal. Um das
Ergebnis auf das Terminal zu schreiben wird einmal ueber die 
Ergebnismatrix in einem Loop iteriert. Jeder Wert wird
geladen und dann ausgegeben und dies wird mit einem Counter 
realisiert. Es wurde ein zweiter Loop realisiert, so, dass die 
Matrix auf dem Terminal die vorgegebene Form hat.
*/
    ldr r0, =str_ergebnis
    bl uart_putString					// String-Ausgabe fuer das Ergebnis

    ldr r4, =result						// Laden von Ergebnisadresse und				
    mov r5, #COUNTER_AUSSEN				// Laden des Counter fuer Zeilen- bzw. Spaltengroesse
    	
print_matrix_aussen:					// Starte aeusseren Loop, fuer die Realisierung von Newlines    
    mov r6, #COUNTER_AUSSEN	
    		
print_matrix_innen:						// Innerer Loop, der die Elemente der Matrix ausgibt   
    ldr r0, [r4], #4					// Lade aktuellen Wert			
    bl uart_putInt32					// Gebe aktuellen Wert aus
    
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    subs r6, r6, #1						// Kontrolliere, die Zeile voll ist, 				
    bne print_matrix_innen				// wenn ja springe zurueck!
    
    mov r0, #NEW_LINE						
    bl uart_putChar						// Gib einen Zeilenumbruch aus
    subs r5, r5, #1						// Kontrolliere, ob die Matrix fertig ist
    bne print_matrix_aussen				// Wenn nicht, springe zurueck

/*
Aufgabenteil (b). 
Hier beginnt das Kopieren des Ergebnisses zu einer weiteren Adresse im 
Speicher. Es wurde im RAM genuegend Platz dafuer vorgesehen, da eine
Variable result_copy angelegt wurde. Zum Kopieren wurden die Befehle
ldm und stm verwendet. Diese erlauben es mehrere Register mit einem 
Befehl zu laden und zu speichern. Dabei wird an den Adressen von r2
bzw. r3 begonnen und die Adresse wird nach jeden Laden/Speichern so
inkrementiert ("!"), dass der naechste Wert der Matrix geladen und
entsprechend gespeichert wird. Beide Befehle werden zwei mal ausgefuehrt,
da nicht genuegen Register vorhanden sind um alle 16 Eintraege der Matrix
auf einmal zu kopieren.
*/
    ldr r0, =str_copy					
    bl uart_putString					// String-Ausgabe fuer das Kopieren
    
    ldr r2, =result						// Laden der Adressen fuer Ergebnis 
    ldr r3, =result_copy				// und Ergebnis-Kopie
    
    // Kopieren der Ergebnismatrix
    ldm r2!, {r4,r5,r6,r7,r8,r9,r10,r11}
    stm r3!, {r4,r5,r6,r7,r8,r9,r10,r11}
    ldm r2!, {r4,r5,r6,r7,r8,r9,r10,r11}
    stm r3!, {r4,r5,r6,r7,r8,r9,r10,r11}
    
/*
Aufgabenteil (c). 
Hier beginnt das Berechnen der Produkt Summe. Aufgrund der Position der 
Matrix N im Speicher kann einfach ueber beiden Matrizen mit einem Loop
iteriert werden. Die Berechnung erfolgt wieder mit dem Befehl smlad und 
die Produkt-Summe wird dadurch nach und nach in r7 akkumuliert und 
schliesslich auf das Terminal ausgegeben. 
*/
    ldr r0, =str_product
    bl uart_putString					// String-Ausgabe fuer Produkt-Summe
    
    mov r4, #COUNTER_PRODUCT			// Vorbreiten des Loops mit Counter
    ldr r5, =matrix_M    				// Laden der Adresse der Matrix M
    ldr r6, =matrix_N 					// Laden der Adresse der Matrix N
    mov r7, #0							// Initialisierung eines Registers fuer das Ergebnis
    
product_sum:							// Loop zur Berechnung der Produkt-Summe
    ldr r8, [r5], #4   					// Lade die beiden aktuellen Werte und
    ldr r9, [r6], #4   					// inkrementiere deren Adressen danach
    smlad r7, r8, r9, r7        		// Multipliziere die aktuellen Werte und addiere sie zum Ergebnis
    subs r4, r4, #1						// Sind alle Eintraege der Matrizen bearbeitet worden?
    bne product_sum						// Wenn nicht springe zurueck!
    
    mov r0, r7							
    bl uart_putInt32					// Ausgabe des Ergebnisses auf das Terminal
    
/*
Aufgabenteil(d).
Hier werden die in der Aufgabenstellung angegebenen Befehle mit den gegebenen
Werte ausprobiert. Nach dem Laden der Werte werden die Befehle nach und nach
durchgegangen. Es werden immer erst die Strings ausgegeben, dann die 
Ergebnisse berechnet und dann die Ergebnisse auf der Terminal ausgegeben.
*/
    // Lade die vorgegebenen Werte in Register fuer die Aufgabenteile (d) und (e)
    ldr r4, =VALUE_A
    ldr r5, =VALUE_B
    ldr r6, =VALUE_C
    ldr r7, =VALUE_D
    
    // Start der Brechnung fuer UADD16
    ldr r0, =str_uadd
    bl uart_putString
    
    uadd16 r8, r4, r5
    mov r0, r8
    bl uart_putInt32
    
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    uadd16 r8, r4, r6
    mov r0, r8
    bl uart_putInt32
    
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    uadd16 r8, r4, r7
    mov r0, r8
    bl uart_putInt32
    
    // Start der Brechnung fuer SADD16
    ldr r0, =str_sadd
    bl uart_putString
    
    sadd16 r8, r4, r5
    mov r0, r8
    bl uart_putInt32
    
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    sadd16 r8, r4, r6
    mov r0, r8
    bl uart_putInt32
    
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    sadd16 r8, r4, r7
    mov r0, r8
    bl uart_putInt32
       
    // Start der Brechnung fuer UQADD16
    ldr r0, =str_uqadd
    bl uart_putString
    
    uqadd16 r8, r4, r5
    mov r0, r8
    bl uart_putInt32
    
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    uqadd16 r8, r4, r6
    mov r0, r8
    bl uart_putInt32
    
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    uqadd16 r8, r4, r7
    mov r0, r8
    bl uart_putInt32
    
    // Start der Brechnung fuer QADD16
    ldr r0, =str_qadd
    bl uart_putString
    
    qadd16 r8, r4, r5
    mov r0, r8
    bl uart_putInt32
    
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    qadd16 r8, r4, r6
    mov r0, r8
    bl uart_putInt32
    
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    qadd16 r8, r4, r7
    mov r0, r8
    bl uart_putInt32
/*
Aufgabenteil (e)
Es werden die Werte fuer A und B der Aufgabenstellung entsprechend 
auf 13 Bit gesaettigt. Hierfuer werden die Befehle USAT16 und SSAT16
verwendet. Es werden immer erst die Strings ausgegeben, dann das 
Ergebnis berechnet und dann das Ergebnis auf der Terminal ausgegeben.
*/   
    // Start der Brechnung fuer USAT16   
    ldr r0, =str_usat
    bl uart_putString
    
    usat16 r8, #SAT_BIT, r4
    mov r0, r8
    bl uart_putInt32
 
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    usat16 r8, #SAT_BIT, r5
    mov r0, r8
    bl uart_putInt32
    
    // Start der Brechnung fuer SSAT16   
    ldr r0, =str_ssat
    bl uart_putString
    
    ssat16 r8, #SAT_BIT, r4
    mov r0, r8
    bl uart_putInt32
 
    mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
    
    ssat16 r8, #SAT_BIT, r5
    mov r0, r8
    bl uart_putInt32
    
    mov r0, #NEW_LINE						
    bl uart_putChar
    mov r0, #NEW_LINE						
    bl uart_putChar
    
end:
	b end

/*** Datenbereich (ab 0x20000000) ***/
.data
matrix_M:   .hword 0x5f8c, 0x7f48, 0x8245, 0x6048
			.hword 0xc799, 0x9c5d, 0xd49c, 0x33d8
			.hword 0x579b, 0x8aef, 0xf2c0, 0xa3c2
			.hword 0x41fd, 0x50d4, 0x25c6, 0x4afa			
matrix_N:	.hword 0x7f41, 0x0645, 0x8c8f, 0x9065
			.hword 0x78e3, 0xf7f3, 0xd29f, 0x2961 
			.hword 0x5a1e, 0xdfed, 0x4b9f, 0x1092
			.hword 0x61bf, 0x21be, 0x5ca1, 0xc6d3
result: .space 64
result_copy: .space 64
str_ergebnis: .asciz "Ergebnismatrix O:\n"
str_copy: .asciz "\nKopieren der Matrix O!\n"
str_product: .asciz "\nProdukt-Summe:  "
str_uadd: .asciz "\n\nUADD16:    "
str_sadd: .asciz "\nSADD16:    "
str_uqadd: .asciz "\nUQADD16: "
str_qadd: .asciz "\nQADD16:    "
str_usat: .asciz "\n\nUSAT16:    "
str_ssat: .asciz "\nSSAT16:    "
