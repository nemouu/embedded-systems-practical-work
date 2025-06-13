/************************************************************
Versuch: 2-3
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 18 Stunden
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

// Konstanten fuer das Einschalten von PIT im SIM
__BBREG SIM_SCGC6_PIT_ADR, 0x4004803C, 23					// Berechnung der BBA des Bit 23 der Basisadresse des SCGC6 Registers des SIM 
.EQU SIM_SCGC6_PIT_ON, 1									// Konstante zum Einschalten von PIT im SIM

// Konstanten fuer das Hinterlegen der ISR in der IVT
.EQU SCR_VTOR_ADR, 0x1ffffe00								// Das Basisadresse der Interrupt Vector Table
.EQU SCR_VTOR_PIT1_OFFSET, 0x00000154						// Offset des Vektors fuer den PIT1
.EQU VTOR_PIT1_ADR, SCR_VTOR_ADR + SCR_VTOR_PIT1_OFFSET     // Adresse des PIT1 Interrupts in der IVT. 

// Konstanten fuer das Einschalten von PIT im NVIC
.EQU NVIC_REG_BITPOS, 0x5									// Bitposition ist 5 fuer PIT1 nach (IRQ mod 32 ist hier 69 mod 32 = 5)
.EQU NVIC_BIT_MSK, 1 << NVIC_REG_BITPOS						// Erstelle Bitmaske fuer die NVIC Register der Bitposition entsprechend
.EQU NVIC_ICPR2_ADR, 0Xe000e288								// Die Adresse des NVIC_ICPR2, um pending Interrupts zu PIT1 zu clearen
.EQU NVIC_ISER2_ADR, 0xe000e108								// Die Adresse des NVIC_ISER2, um Interrupt zu PIT1 zu aktivieren

// Konstanten fuer die Konfiguration von PIT1
__BBREG PIT_MCR_MDIS_ADR, 0x40037000, 1						// Berechnung der BBA des Bit 1 der Basisadresse des PIT_MCR Registers des PIT Modules (Enable)
__BBREG PIT_MCR_FRZ_ADR, 0x40037000, 0						// Berechnung der BBA des Bit 0 der Basisadresse des PIT_MCR Registers des PIT Modules (Debug)
.EQU PIT_MCR_MDIS_ON, 0										// Konstante zum Einschalten des PIT-Modules
.EQU PIT_MCR_FRZ_ON, 1										// Konstante zum Einschalten des Debug-Modues des PIT-Modules

.EQU PIT_LDVAL1_ADR, 0x40037110								// Adresse des Startwertes fuer den PIT1
.EQU PIT_START_VAL, 0x017d7840								// Startwert fuer den PIT1 (orientiert sich an der angenommmenen System Clock (25MHz))
__BBREG PIT_TCTRL1_TIE_ADR, 0x40037118, 1					// Berechnung der BBA des Bit 1 der Basisadresse des PIT_TCTRL1 Registers des PIT Modules (Timer Interrupt Enable)
__BBREG PIT_TCTRL1_TEN_ADR, 0x40037118, 0					// Berechnung der BBA des Bit 0 der Basisadresse des PIT_TCTRL1 Registers des PIT Modules (Timer Enable)
.EQU PIT_TCTRL1_TIE_ON, 1									// Konstante zum Einschalten des Interrupt Timers des PIT1
.EQU PIT_TCTRL1_TEN_ON, 1									// Konstante zum Einschalten des Timers des PIT1
.EQU PIT_TCTRL1_TEN_OFF, 0									// Konstante zum Ausschalten des Timers des PIT1

// Konstanten fuer das Interrupt Flag des PIT1
__BBREG PIT_TFLG1_TIF_ADR, 0x4003711c, 0					// Berechnung der BBA des Bit 0 der Basisadresse des PIT_TFLG1 Registers des PIT Modules (Interrupt Flag)
.EQU PIT_TFLG1_TIF_CLR, 1									// Konstante zum clearen des Interrupt Flags des PIT1 

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init
	
/*
Initialisierung des PIT1 und NVIC fuer die ISR des PIT1(isr_pit1). Hier werden
die Schritte in den Hinweisen zu dieser Aufgabe nach und nach abgearbeitet. Erst
wird die Clock fuer den PIT im SIM aktiviert. Dann laden wir die Adresse der ISR
in die passende Stelle der IVT und danach werden (moeglicherweise) wartende 
Interrupts zum PIT1 im NVIC geloescht. Nun werden im NVIC auch noch die Interrupts zu 
PIT1 aktiviert und danach beginnen wir mit der Konfiguration des PIT-Moduls. Zuerst
wird dieses eingeschaltet und der Debug Modus aktiviert und dann wird Startwert
fuer den PIT1 geladen. Anschliessend wird nur noch der Interrupt Timer des PIT1
selber aktiviert. Der PIT1 Timer selbst wird dann im Hauptprogramm aktiviert. Das
haengt damit zusammen, dass dieser auch waehrend der Ausfuehrung abgeschaltet werden
kann und somit sowieso immer wieder aktiviert werden muss. 
*/

    ldr r0, =SIM_SCGC6_PIT_ADR    // Lade Adresse eines Registers des SIM, um die PIT Clock zu aktivieren
    mov r1, #SIM_SCGC6_PIT_ON	  // Lade Aktivierungsbit
    strb r1, [r0]				  // Aktiviere die PIT Clock des SIM

	ldr r0, =VTOR_PIT1_ADR		  // Lade die oben berechnete Adresse des PIT1 in der IVT
	ldr r1, =isr_pit1			  // Lade die Adresse der erstellten ISR zum PIT1
	str r1, [r0]				  // Speichere Adresse der ISR an der berechneten Adresse

	ldr r0, =NVIC_BIT_MSK		  // Lade die oben berechnete Bitmaske fuer den PIT1
	ldr r1, =NVIC_ICPR2_ADR		  // Setze das entsprechende Bit im NVIC_ICPR2, um
	str r0, [r1]				  // pending Interrupts zu PIT1 löschen.
	ldr r1, =NVIC_ISER2_ADR		  // Setze das entsprechende Bit im NVIC_ISER2, um
	str r0, [r1]				  // Interrupts im NVIC zu PIT1 aktivieren.

	mov r0, #PIT_MCR_MDIS_ON	  // Aktivieren des PIT-Moduls. Dies ist noetig fuer
	ldr r1, =PIT_MCR_MDIS_ADR	  // die weitere Konfiguration des PIT
	strb r0, [r1]
	
	mov r0, #PIT_MCR_FRZ_ON		  // Aktivieren des Debug Modus des PITs, so,
	ldr r1, =PIT_MCR_FRZ_ADR      // dass der PIT anhaelt, wann immer ein Breakpoint 
	strb r0, [r1]				  // erreicht wird.	

	ldr r0, =PIT_LDVAL1_ADR		  // Initialisiere den Startwert fuer PIT1,
	ldr r1, =PIT_START_VAL		  // so, dass jede Sekunde ein Interrupt
	str r1, [r0]				  // ausgeloest wird.

	mov r0, #PIT_TCTRL1_TIE_ON	  // Aktivieren den Interrupt Timer des PIT,
	ldr r1, =PIT_TCTRL1_TIE_ADR	  // indem wir in das TIE Bit des TCTRL1 Registers 
	strb r0, [r1]				  // eine 1 schreiben.

	bl print_current_date		  // Das initiale Datum und die Uhrzeit wird gedruckt.
	
start:
	ldr r0, =user_flag			  // Setze Benutzer Flag wieder auf 0,
	mov r1, #0					  // damit wieder auf einen Interrupt gewartet werden kann.	
	strb r1, [r0]
	
	mov r0, #PIT_TCTRL1_TEN_ON	  // Aktivierte den Timer des PIT, sowohl beim ersten Mal
	ldr r1, =PIT_TCTRL1_TEN_ADR	  // als auch falls dieser durch ein Zeichen ('s', 't' oder 'd')
	strb r0, [r1]				  // gestoppt wurde.
	
	bl delay					  // Wechsel zum UP, das das Warten von einer Sekunde (hier mithilfe einer ISR) realisiert

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
	mov r0, #PIT_TCTRL1_TEN_OFF	  // Stoppe den PIT Timer, da die Uhr auch gestoppt wird. So werden keine
	ldr r1, =PIT_TCTRL1_TEN_ADR	  // Interrupts erzeugt, wenn die Uhr still steht. Wird wieder in den start
	strb r0, [r1]				  // Teil des Programmes gewechselt, wird der Timer des PIT wieder aktiv.
								  
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
Interrupt Service Routine fuer PIT1. Ist die Zeit des PIT1 Startwertes abgelaufen wird
ein Interrupt ausgeloest und die folgende ISR ausgefuehrt. In dieser wird das Interrupt
Flag des PIT und das Benutzer-Flag zurueck gesetzt. 
*/
.thumb_func
isr_pit1:
	ldr r0, =PIT_TFLG1_TIF_ADR	  // Lade die Adresse des Interrupt Flag zu PIT1
	mov r1, #PIT_TFLG1_TIF_CLR	  // Lade Clear-Bit fuer das Interrupt Flag zu PIT1
	strb r1, [r0]				  // Loesche das Interrupt Flag zu PIT1

	ldr r0, =user_flag			  // Lade Adresse des Benutzer-Flags und setze Benutzer-Flag auf 1 					  
	strb r1, [r0]				  // (wird dann im HP zurueckgesetzt), in r1 steht noch die 1 (wird 
	          	  	  	  	      // nicht nochmal geladen, um die ISR schneller abzuarbeiten)
	bx lr

/*
Ein Unterprogramm, das eine Uhrzeit entgegenimmt und sie im Speicher ablegt. Zuerst wird eine Zahl
fuer die Stunde und dann fuer die Minute eingelesen und schliesslich im Speicher abgelegt. Am Schluss
wird die aktuelle Zeit und das aktuelle Datum noch einmal ausgegeben, da der Benutzer so direkt ein 
Update erhaelt.
*/
.thumb_func
write_new_time:
	push {lr}

	mov r0, #PIT_TCTRL1_TEN_OFF		// Stoppe den PIT Timer, da die Uhr auch gestoppt wird. So werden keine
	ldr r1, =PIT_TCTRL1_TEN_ADR	    // Interrupts erzeugt, wenn die Uhr still steht. Wird wieder in den start
	strb r0, [r1]				    // Teil des Programmes gewechselt, wird der Timer des PIT wieder aktiv.

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

	mov r0, #PIT_TCTRL1_TEN_OFF		// Stoppe den PIT Timer, da die Uhr auch gestoppt wird. So werden keine
	ldr r1, =PIT_TCTRL1_TEN_ADR	    // Interrupts erzeugt, wenn die Uhr still steht. Wird wieder in den start
	strb r0, [r1]				    // Teil des Programmes gewechselt, wird der Timer des PIT wieder aktiv.

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
	push {lr}
	
delay_loop:
	ldr r0, =user_flag			// Lade die Adresse des Benutzer-Flag
	ldrb r1, [r0]				// Lade den entsprechenden Byte der an der obigen Adresse steht
	cmp r1, #1					// Bleibe so lange in delay_loop bis die Benutzer Flag
	bne delay_loop				// gleich 1 ist, dann verlasse den Loop
	
	pop {pc}
	
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
user_flag: .byte 0x0
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
