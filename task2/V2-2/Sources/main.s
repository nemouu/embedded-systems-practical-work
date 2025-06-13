/************************************************************
Versuch: 2-2
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 12 Stunden
************************************************************/

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
.EQU COUNTER_DELAY, 0x7f2815	// Konstante fuer das Delay-Unterprogramm
.EQU MAX_TAG, 0x1f				// Die groesste Zahl fuer einen Tag (31)
.EQU MAX_MONAT, 0xd				// Die groesste Zahl fuer einen Monat (13)
.EQU MAX_STUNDE, 0x18			// Die groesste Zahl fuer eine Stunde (24)
.EQU MAX_MINUTE, 0x3c			// Die groesste Zahl fuer eine Minute (60)
.EQU MAX_JAHR, 0x64				// Die groesste Zahl fuer ein Jahrhundert (100)
.EQU NEW_LINE, 0x0a				// Konstante fuer die neue Zeile (Ascii-Code)
.EQU SPACE, 0x20				// Konstante fuer das Leerzeichen (Ascii-Code)
.EQU DOT, 0x2e					// Konstante fuer den Punkt (Ascii-Code)
.EQU COLON, 0x3a				// Konstante fuer das Semikolon (Ascii-Code)
.EQU BASE_TEN_MAX, 0xa			// Konstante fuer fuehrende Null
.EQU LEADING_ZERO, 0x30			// Konstante fuer eine Null, sodass diese im Falle einer fuehrenden Null eingefuegt werden kann
.EQU START_VAL_MINHY, 0x0		// Konstante fuer Startwert von Minute, Stunde und Jahr
.EQU START_VAL_DMON, 0x1		// Konstante fuer Startwert von Tag und Monat

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init
	bl print_current_date		  // Das initiale Datum und die Uhrzeit wird gedruckt
start:
	bl delay					  // Wechsel zum UP, das das Warten von einer Sekunde (mit einem Loop) realisiert

	ldr r0, =minute				  // Lade Adresse von Minute fuer die Uebergabe	
    mov r1, #MAX_MINUTE           // Lade den Grenzwert der Minute
    mov r2, #START_VAL_MINHY      // Setze r2 auf den Startwert für Minute
    bl incr_time          		  // Inkrementiere die Minuten
    teq r1, #1                    // Teste auf Ueberlauf
    bne print       			  // Kein Ueberlauf, fahre mit der Ausgabe fort
    
    ldr r0, =stunde				  // Lade Adresse von Stunde fuer die Uebergabe	
    mov r1, #MAX_STUNDE           // Lade den Grenzwert der Stunde
    mov r2, #START_VAL_MINHY      // Setze r2 auf den Startwert für Stunde
    bl incr_time         		  // Inkrementiere die Stunden
    teq r1, #1                    // Teste auf Ueberlauf
    bne print       			  // Kein Ueberlauf, fahre mit der Ausgabe fort
    
    ldr r0, =tag				  // Lade Adresse von Tag fuer die Uebergabe		
    mov r1, #MAX_TAG              // Lade den Grenzwert der Tag
    mov r2, #START_VAL_DMON       // Setze r2 auf den Startwert für Tag
    bl incr_time         		  // Inkrementiere die Tage
    teq r1, #1                    // Teste auf Ueberlauf
    bne print       			  // Kein Ueberlauf, fahre mit der Ausgabe fort
    
    ldr r0, =monat			      // Lade Adresse von Monat fuer die Uebergabe		
    mov r1, #MAX_MONAT            // Lade den Grenzwert der Monat
    mov r2, #START_VAL_DMON       // Setze r2 auf den Startwert für Monat
    bl incr_time        		  // Inkrementiere die Monate
    teq r1, #1                    // Teste auf Ueberlauf
    bne print       			  // Kein Ueberlauf, fahre mit der Ausgabe fort
    
    ldr r0, =jahr2			      // Lade Adresse von Jahr(hintere Stellen) fuer die Uebergabe		
    mov r1, #MAX_JAHR             // Lade den Grenzwert der Jahr(hintere Stellen)
    mov r2, #START_VAL_MINHY      // Setze r2 auf den Startwert für Jahr(hintere Stellen)
    bl incr_time         		  // Inkrementiere die Jahre(hintere Stellen)

print:
	bl print_current_date		  // Das aktuelle Datum wird gedruckt
	
	bl uart_charPresent			  // Pruefe, ob ein Zeichen im Terminal angekommen ist und
	teq r0, #0					  // schreibe 0 in r0, falls ein Zeichen angekommen ist. 
	bne char_present_running	  // Wechsel zum Abschnitt char_present_running falls ein Zeichen da ist 
	  
	b start						  // Sonst wird wieder zurueckgesprungen und die Zeit/Datum erhoeht und gedruckt

char_present_running:			  // Hierhin wird gewechselt, falls die Uhr lief und ein Zeichen da ist
	bl uart_getChar				  // Lese das Zeichen vom Terminal ein
	
	cmp r0, #'s'				  
	beq stop					  // Ist dieses Zeichen "s" so wird zu stop gesprungen (Stopp der Uhr)

	cmp r0, #'t'				
	it eq						  // Ist dieses Zeichen "t", so wird zu write_new_time gesprungen, das
	bleq write_new_time           // heisst es kann eine neue Zeit eingegeben werden
	
	cmp r0, #'d'
	it eq						  // Ist dieses Zeichen "d", so wird zu write_new_date gesprungen, das
	bleq write_new_date   		  // heisst es kann eine neues Datum eingegeben werden
	
	b start						  // Ist das Zeichen ungleich der oben aufgefuehrten Zeichen, springe zurueck
								  // zurueck zu Ausganszustand (hier: start)

stop:							  // Abschnitt fuer die Uhr, wenn sie gestoppt ist (es findet kein Drucken und keine Erhoehung statt).
	bl uart_charPresent			  // Pruefe, ob ein Zeichen im Terminal angekommen ist und
	teq r0, #0					  // schreibe 0 in r0, falls ein Zeichen angekommen ist. 
	bne char_present_stopped	  // Wechsel zum Abschnitt char_present_running falls ein Zeichen da ist
	
	b stop						  // Sonst wird wieder zurueckgesprungen und die Uhr bleibt gestoppt
	
char_present_stopped:			  // Hierhin wird gewechselt, falls die Uhr nicht lief und ein Zeichen da ist
	bl uart_getChar				  // Lese das Zeichen vom Terminal ein
	
	cmp r0, #'s'
	beq start					  // Ist dieses Zeichen "s" so wird zu stop gesprungen (Stopp der Uhr)
	
	cmp r0, #'t'				  
	it eq						  // Ist dieses Zeichen "t", so wird zu write_new_time gesprungen, das
	bleq write_new_time			  // heisst es kann eine neue Zeit eingegeben werden
	
	cmp r0, #'d'
	it eq						  // Ist dieses Zeichen "d", so wird zu write_new_date gesprungen, das
	bleq write_new_date 		  // heisst es kann eine neues Datum eingegeben werden
	
	b stop						  // Ist das Zeichen ungleich der oben aufgefuehrten Zeichen, springe 
								  // zurueck zu Ausganszustand (hier: stop)

/*
Ein Unterprogramm, das eine Uhrzeit entgegenimmt und sie im Speicher ablegt. Zuerst wird eine Zahl
fuer die Stunde und dann fuer die Minute eingelesen und schliesslich im Speicher abgelegt. Am Schluss
wird die aktuelle Zeit und das aktuelle Datum noch einmal ausgegeben, da der Benutzer so direkt ein 
Update erhaelt.
*/
.thumb_func
write_new_time:
	push {lr}

	ldr r0, =str_new_stunde			// String Adresse laden
	bl uart_putString				// String ausgeben
	bl uart_getByteBase10			// ein Byte einlesen
	ldr r1, =stunde					// Adresse von Stunde im Speicher laden
	strb r0, [r1]					// und das eingelesene Byte an dieser Adresse ablegen
	bl uart_putByteBase10			// Byte ausgeben
	
	ldr r0, =str_new_minute			// String Adresse laden
	bl uart_putString				// String ausgeben
	bl uart_getByteBase10			// ein Byte einlesen
	ldr r1, =minute					// Adresse von Minute im Speicher laden
	strb r0, [r1]					// und das eingelesene Byte an dieser Adresse ablegen
	bl uart_putByteBase10			// Byte ausgeben
			
	mov r0, #NEW_LINE						
    bl uart_putChar					
	mov r0, #NEW_LINE						
    bl uart_putChar					
	
	bl print_current_date			// Drucke das aktuelle Datum mit der neuen Uhrzeit
			
	pop {pc}
	
/*
Ein Unterprogramm, das ein Datum entgegenimmt und sie im Speicher ablegt. Zuerst wird eine Zahl
fuer den Tag, dann fuer den Monat und schliesslich fuer das Jahr eingelesen. Die Zahlen fuer Tag
und Monat werden im Speicher abgelegt. Bei der Zahl fuer das Jahr wird die Eingabe so behandelt,
dass daraus eine vierstelle Jahreszahl ensteht. Aus einer Eingabe jj wird dann also jjjj. Am Schluss
wird die aktuelle Zeit und das aktuelle Datum noch einmal ausgegeben, da der Benutzer so direkt 
ein Update erhaelt.
*/
.thumb_func
write_new_date:
	push {lr}

	ldr r0, =str_new_tag			// String Adresse laden
	bl uart_putString				// String ausgeben
	bl uart_getByteBase10			// ein Byte einlesen
	ldr r1, =tag					// Adresse von Tag im Speicher laden
	strb r0, [r1]					// und das eingelesene Byte an dieser Adresse ablegen
	bl uart_putByteBase10			// Byte ausgeben
	
	ldr r0, =str_new_monat			// String Adresse laden
	bl uart_putString				// String ausgeben
	bl uart_getByteBase10			// ein Byte einlesen
	ldr r1, =monat					// Adresse von Monat im Speicher laden
	strb r0, [r1]					// und das eingelesene Byte an dieser Adresse ablegen
	bl uart_putByteBase10			// Byte ausgeben
	
	ldr r0, =str_new_jahr			// String Adresse laden
	bl uart_putString				// String ausgeben
	bl uart_getByteBase10			// ein Byte einlesen
	ldr r2, =jahr2					// Adresse von Jahr2 im Speicher laden
	strb r0, [r2]					// und das eingelesene Byte an der Adresse von Jahr2 ablegen
	bl uart_putByteBase10			// Byte ausgeben
	
	mov r0, #NEW_LINE						
    bl uart_putChar					
	mov r0, #NEW_LINE						
    bl uart_putChar					
	
	bl print_current_date			// Drucke das neue Datum mit der aktuellen Uhrzeit
	
	pop {pc}		

/*
Unterprogramm der Teilaufgabe (a) entsprechend. Da wir davon ausgehen, dass
der K60 mit 25MHz = 25000000Hz getaktet wird, muessen wir eine Schleife so
erstellen, dass waehrend ihrer Ausfuehrung eine Sekunde vergeht. Es wurde
also eine Konstante mit dem Wert 25000000/3 (gerundet) angelegt und der Loop 
in diesem Unterprogramm zaehlt dann einfach nur auf 0 runter. Dieser Wert 
wurde geaehlt, da fuer einen Durchgang des Loops in der Regel 3 Takte benoetigt 
werden. 
*/
.thumb_func
delay:
	ldr r1, =COUNTER_DELAY		// Lade den Zaehler fuer die Verzoegerung
delay_loop:
	subs r1, r1, #1				// Bleibe so lange in delay_loop bis der
	bne delay_loop				// geladene Zaehler gleich Null ist
	
	bx lr
	
/*
Unterprogramm der Teilaufgabe (b) entsprechend. Hierbei wird das 
komplette aktuelle Datum mit Uhrzeit auf das Terminal ausgegeben. 
Dazu werden die Adressen der einzelnen Zeitwerte geladen und 
schliesslich dem weiter unten angegebenen print_curr_value 
Unterprogramm uebergeben. Insgesamt wird durch diese beiden 
Unterprogramme das Drucken des aktuellen Datums realisiert.
*/
.thumb_func
print_current_date:
	push {lr}					// Schiebe lr auf den Stack, da es weitere UP-Aufrufe gibt
	
	ldr r1, =tag				// Lade Adresse von Tag und 
	ldrb r0, [r1]				// uebergebe den Wert an print_curr_value
	bl print_curr_value			// Drucke Tage

	mov r0, #DOT
	bl uart_putChar

	ldr r1, =monat				// Lade Adresse von Monat und
	ldrb r0, [r1]				// uebergebe den Wert an print_curr_value
	bl print_curr_value			// Drucke Monate

	mov r0, #DOT
	bl uart_putChar

	ldr r1, =jahr1				// Lade Adresse der vorderen Stellen von Jahr und
	ldrb r0, [r1]				// uebergebe den Wert an print_curr_value
	bl print_curr_value			// Drucke vordere Stelle von Jahr
	
	ldr r1, =jahr2				// Lade Adresse der hintere Stellen von Jahr und
	ldrb r0, [r1]				// uebergebe den Wert an print_curr_value
	bl print_curr_value			// Drucke hintere Stelle von Jahr

	mov r0, #SPACE
    bl uart_putChar
    mov r0, #SPACE
    bl uart_putChar
	
	ldr r1, =stunde				// Lade Adresse von Stunde und
	ldrb r0, [r1]				// uebergebe den Wert an print_curr_value
	bl print_curr_value			// Drucke Stunden

	mov r0, #COLON		
	bl uart_putChar

	ldr r1, =minute				// Lade Adresse von Minute und
	ldrb r0, [r1]				// uebergebe den Wert an print_curr_value
	bl print_curr_value			// Drucke Minuten

	ldr r0, =str_clock		
	bl uart_putString
	
	pop {pc}
	
/*
Unterprogramm, das zur Teilaufgabe (b) gehoert und ein Byte entweder mit
vorgestellter 0 (wenn es kleiner als 10 ist) oder sonst ganz normal ausgibt.
Hierbei wird in

-r0 der aktuell betrachtete Zeitwert 

uebergeben. Dann wird geprueft, ob eine fuehrende 0 eingefuegt werden muss oder
nicht und schliesslich wird die entsprechende Zahl auf das Terminal ausgegeben.
*/
.thumb_func
print_curr_value:
    push {lr}
    
    mov r1, r0                 // Zwischenspeichern des aktuell betrachteten Zeitwertes   
    cmp r1, #BASE_TEN_MAX      // Ist dieser Wert groesser gleich 10,
    it ge
    bge skip_zero			   // so kann die Ausgabe einer fuehrenden 0 uebersprungen werden.
    mov r0, #LEADING_ZERO			  
    bl uart_putChar            // Ansonsten wird zunaechst eine fuehrende 0 ausgegeben.
    
skip_zero:
    mov r0, r1
    bl uart_putByteBase10      // Hier wird dann die uebergebene Zahl ausgegeben. 
    
    pop {pc}

/*
Ein Unterprogramm, dass den Wert eines uebergebenen Zeitwertes erhoeht. Hierbei
kann in 

-r0 die Adresse des zu erhoehenden Zeitwertes, in
-r1 der Grenzwert fuer den aktuellen Zeitwert und in
-r2 der Startwert fuer den aktuellen Zeitwert

uebergeben werden. Es wird hier also auch der Uberlauf behandelt. Es wird in 

-r1 wird der Überlauf des Zeitwertes abgelegt

und damit kann dann in den Befehlen nach dem return aus diesem Unterprogramm
entschieden werden, ob der naechste Zeitwert auch erhoeht werden muss (geht zB
der Wert von Minute von 59 -> 00, so muss der Wert fuer Stunde auch erhoeht
werden).
*/
.thumb_func
incr_time:
    ldrb r3, [r0]              // Lade den aktuellen Zeitwert aus dem Speicher
    add r3, r3, #1             // Erhoehe den Zeitwert
    cmp r3, r1                 // Pruefe, ob ein Ueberlauf entsteht
    itte eq
    moveq r3, r2               // Es gab einen Ueberlauf, setze den Zeitwert zurueck
    moveq r1, #1			   // und lade hier den dem Ueberlauf entsprechenden
    movne r1, #0			   // Wert in r1
    strb r3, [r0]              // Lege den neuen Zeitwert an gegebener Adresse im Speicher ab

    bx lr
    
/*** Datenbereich (ab 0x20000000) ***/
.data
tag: .byte 0x01
monat: .byte 0x01
jahr1: .byte 0x14
jahr2: .byte 0x0e
stunde: .byte 0x00
minute: .byte 0x00
str_clock: .asciz " Uhr\n"
str_new_tag: .asciz "\nTag eingeben (dd): "
str_new_monat: .asciz "\nMonat eingeben (mm): "
str_new_jahr: .asciz "\nJahr eingeben (jj): "
str_new_stunde: .asciz "\nStunde eingeben (hh): "
str_new_minute: .asciz "\nMinuten eingeben (mm): "
