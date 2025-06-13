/************************************************************
Versuch: 4-1
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 40 Stunden
************************************************************/

// Include-Dateien
.include "k1514.inc"				// Praktikumsspezifische Definitionen
.include "lib_pit.inc"				// Einfache Unterprogramme zur Zeitmessung
.include "lib_uart.inc"				// Unterprogramme zur Ein-/Ausgabe vom/zum Terminal (CuteCom)

// Assemblerdirektiven
.text								// hier beginnt ein Code-Segment
.align	2							// Ausrichtung an eine gerade Adresse
.global	main						// "main" wird als globales Symbol deklariert
.syntax unified

// Konstanten fuer Registeradressen
.equ SIM_SCGC3,		0x40048030
.equ SIM_SCGC5,     0x40048038
.equ SIM_SCGC6,	 	0x4004803C
.equ SCR_VTOR,		0xE000ED08		// Register für die Interrupt-Vektor-Tabelle (IVT)

.equ PIT_MCR,       0x40037000
.equ PIT_LDVAL1,    0x40037110
.equ PIT_TCTRL1,    0x40037118
.equ PIT_TFLG1,     0x4003711C

.equ NVIC_ISER2, 	0xe000e108
.equ NVIC_ICPR2, 	0xe000e288

.equ GPIOA_PDOR,    0x400FF000
.equ GPIOA_PDIR,    0x400FF010
.equ GPIOA_PDDR,    0x400FF014

.equ PORTA_PCR0,	0x40049000		// Start-Adresse der Port A PCR-Register


// Bit Band-Konstanten
__BBREG SIM_PIT, SIM_SCGC6, 23			// Bit-Band-Alias-Adresse für den PIT im SIM-Register
__BBREG	SIM_PORTA, SIM_SCGC5, 9			// Bit-Band-Alias-Adresse für das PORTA im SIM-Register
__BBREG	SIM_ADC1, SIM_SCGC3, 27			// Bit-Band-Alias-Adresse für das ADC1 im SIM-Register
__BBREG PIT_CTRL1_TEN, PIT_TCTRL1, 0    // Bit-Band-Alias-Adresse für das TEN Bit im PIT1 Kontroll-Register

__BBREG	E1, GPIOA_PDOR, 11
__BBREG	E2, GPIOA_PDOR, 28
__BBREG	E3, GPIOA_PDOR, 29
__BBREG	E4, GPIOA_PDOR, 10


// weitere Konstanten
.equ ONE_SECOND, 25000000-1			// 25.000.000 Takte bei 25 MHz
.equ CONFIG_DELAY, 1100				// 
.equ LF, 0x0A						// Line Feed (neue Zeile)
.equ SP, 0x20						// Space
.equ CHAR_S, 's'
.equ CHAR_0, '0'
.equ CHAR_1, '1'
.equ CHAR_2, '2'
.equ CHAR_3, '3'

.equ PIT1_IRQ_OFS,	0x154			// Interrupt Request Offset für PIT1
.equ PIT1_NVIC_MASK, 1 << (69 % 32)	// Bitposition für PIT-IRQ in NVIC-Registern (IRQ mod 32)

.equ PIT_COUNT, 25000000			// 25000000	Takte bei 25 MHz => 1 Sekunde
.equ PIT_MCR_VAL, 0					// MDIS = 0, FRZ = 0
.equ PIT_TCTRL1_VAL, 3				// CHN = 0, TIE = 1, TEN = 1

.equ PDDR_MASK_LED, (1<<10 | 1<<11 | 1<<28 | 1<<29)	// Maske fuer die LEDs E1 bis E4

.equ GPIO_SET, 0x120				// GPIO-Modus, Open-Drain
.equ GPIO_PE_SET, 0x103				// GPIO-Modus, Pull-Up-Widerstand
.equ GPIO_IRQ_PE_SET, 0xA0103		// GPIO-Modus, IRQ (fallende Flanke), Pull-Up-Widerstand

.equ UPPER_LIMIT, 0xce4				// Obere Grenze fuer die Ausgabe in mV (3300 mV = 3.3V). Die Angaben wurden dem Schaltplan entnommen.
.equ POTI_MAX, 0x10000				// Obere Grenze fuer den Wert des Potis fuer die Stufenberechnung

// Offsets für die einzelnen PCR-Register
.equ PCR10,	0x28					// E4
.equ PCR11,	0x2C					// E1
.equ PCR28,	0x70					// E2
.equ PCR29,	0x74					// E3

// ADC Konfiguration und Initialisierung
.equ CFG1_INIT_VAL,	0x6c			// normal power, divide ratio: (input clock)/8 (3,125Mhz), short sample time, Conversion mode 16 Bit, input clock = Bus clock 
.equ CFG2_INIT_VAL,	0x0				// ADxxa is selected, async Clock disabled, normal conversion sequence, longest sample time
.equ SC2_INIT_VAL,	0x0				// Software trigger enabled, compare disabled, DMA disabled, default voltage
.equ SC3_INIT_VAL,	0xe				// continous conversion enabled, hardware average enabled, 16 samples averaged
.equ SC1A_INIT_VAL, 0x14			// AD20 (Poti) ausgewaehlt, Interrupts aus, Single ended Modus ausgewaehlt
.equ SC1A_STOP_VAL, 0x1f			// Modul angehalten (Wandlung gestoppt), Interrupts aus, Single ended Modus ausgewaehlt

// ADC Genauigkeitswerte fuer spaetere Aenderung waehrend der Programmausfuehrung
.equ CFG1_MODE_8,  0x0				// Wert fuer ADC1_CFG1_MODE bei 8 Bit Wandlung
.equ CFG1_MODE_12, 0x4				// Wert fuer ADC1_CFG1_MODE bei 12 Bit Wandlung
.equ CFG1_MODE_10, 0x8				// Wert fuer ADC1_CFG1_MODE bei 10 Bit Wandlung
.equ CFG1_MODE_16, 0xc				// Wert fuer ADC1_CFG1_MODE bei 16 Bit Wandlung

// Adressen fuer Nutzung und Konfiguration von ADC1
.equ ADC1_SC1A, 0x400bb000			// Adresse von SC1A, die auch als Basisadresse fuer die unten genannten Register (Offsets) fungiert

// Offsets fuer Adressen von ADC1
.equ RA, 	0x10
.equ CFG1,	0x8
.equ CFG2,	0xc
.equ SC2,	0x20
.equ SC3,	0x24
.equ PG,	0x2c
.equ CLPS,	0x38
.equ CLP4,	0x3c
.equ CLP3,	0x40
.equ CLP2,	0x44
.equ CLP1,	0x48
.equ CLP0,	0x4c

// Bitmasken fuer die Konfiguration/Kalibrierung vom ADC1 (so werden nur die Bits geaendert, die wir auch aendern wollen)
.equ BIT_MASK70, 	0xff			// Fuer die Bits 7 bis 0 
.equ BIT_MASK7630, 	0xcf			// Fuer die Bits 7 und 6 und 3 bis 0
.equ BIT_MASK40, 	0x1f			// Fuer die Bits 4 bis 0
.equ BIT_MASK32, 	0xc				// Fuer die Bits 3 und 2
.equ BIT_MASK7,		0x80			// Fuer das Bit 7
.equ BIT_MASK6,		0x40			// Fuer das Bit 6

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init					// UART initialisieren	
	bl gpio_leds_init				// GPIO zur LED Ausgabe initialisieren	
	bl pit1_init					// PIT1 initialisieren

// Haeufig verwendete Werte und Adressen vorbelegen
	ldr r12, =ADC1_SC1A
	ldr r11, =PIT_CTRL1_TEN
	ldr r10, =pit1_flag
	ldr r9, =running
	ldr r8, =mode
	mov r7, #1
	
/*
 * Hier beginnt Konfiguration, Initialisierung des ADC1 und es wird auch in die Funktion gesprungen,
 * die fuer die Kalibrierung des ADC1 zustaendig ist. Dazu werden zuerst die Register CFG1, CFG2, SC2
 * und SC3 entsprechend initialisiert. Dann wird der ADC1 kalibriert und falls diese Kalibrierung 
 * fehlschlaegt, dann wird nochmal von vorne begonnen. Schliesslich wird das SCA1 Register mit dem
 * dem Poti entsprechenden Wert beschrieben und somit die Konvertierung gestartet.
 */
start_adc_config:	
	// Takt fuer den ADC1 im SIM aktivieren
	ldr r0, =SIM_ADC1
	str r7, [r0]
	
    // Konfiguration von CFG1
    ldr r0, [r12, #CFG1]			// Lade Inhalt des CFG1 Registers in r1
    bic r0, r0, #BIT_MASK70			// Cleare die Bits, die wir setzen wollen (Bits 7-0)
    orr r0, r0, #CFG1_INIT_VAL		// Setze die gewuenschten Bits (CFG1_INIT_VAL)
    str r0, [r12, #CFG1]			// Schreibe den Wert zurueck in das CFG1 register
    
    // Konfiguration von CFG2
    ldr r0, [r12, #CFG2] 			// Lade Inhalt des CFG1 Registers in r1
    bic r0, r0, #BIT_MASK40			// Cleare die Bits, die wir setzen wollen (Bits 4-0)
    orr r0, r0, #CFG2_INIT_VAL		// Setze die gewuenschten Bits (CFG2_INIT_VAL)
    str r0, [r12, #CFG2]			// Schreibe den Wert zurueck in das CFG2 register
    
    // Konfiguration von SC2
    ldr r0, [r12, #SC2] 			// Lade Inhalt des SC2 Registers in r1
    bic r0, r0, #BIT_MASK70			// Cleare die Bits, die wir setzen wollen (Bits 7-0)
    orr r0, r0, #SC2_INIT_VAL		// Setze die gewuenschten Bits (SC2_INIT_VAL)
    str r0, [r12, #SC2]				// Schreibe den Wert zurueck in das SC2 register
    
    // Konfiguration von SC3
    ldr r0, [r12, #SC3] 			// Lade Inhalt des SC3 Registers in r1
    bic r0, r0, #BIT_MASK7630		// Cleare die Bits, die wir setzen wollen (Bits 7 und 6 und Bits 3-0)
    orr r0, r0, #SC3_INIT_VAL		// Setze die gewuenschten Bits (SC3_INIT_VAL)
    str r0, [r12, #SC3]				// Schreibe den Wert zurueck in das SC3 register

    // Kalibrierung des ADC1
	bl adc_cal						// Springe zur Funktion um den ADC zu kalibrieren
	
	ldr r0, =cal_failed				// Lade erst die Adresse
	ldr r1, [r0]					// und dann den Wert des Kalibrierung fehlgeschlagen Flags
	tst r1, #1						// Prufe, ob dieses gleich eins ist und ist dies der Fall
	bne start_adc_config			// Dann springe zum Anfang der Konfiguration zurueck und starte erneut
	
	// Konfiguration von SC1A
    ldr r0, [r12] 					// Lade Inhalt des SC1A Registers in r1
    bic r0, r0, #BIT_MASK70			// Cleare die Bits, die wir setzen wollen (bits 7-0)
    orr r0, r0, #SC1A_INIT_VAL		// Setze die gewuenschten Bits (SC1A_INIT_VAL)
    str r0, [r12]					// Schreibe den Wert zurueck in das SC1A register

/* 
 * Es folgt eine Zaehlschleife, um korrekte Terminalausgabe zu ermoeglichen (sonst wird bei der ersten Ausgabe eine 0000 
 * als Messwert ausgegeben). Moeglicherweise muss hier zunaechst einige Takte darauf gewartet warten, dass die erste 
 * Konvertierung abgeschlossen ist. Da dazu aber weniger als eine Sekunde ausreicht, wurde hier ein eigener kleiner Loop
 * eingesetzt.
 */	

    ldr r0, =CONFIG_DELAY    		// Lade den Zaehlschleifenwert in r0
config_loop:						// Zaehlschleife, um korrekte Terminalausgabe zu ermoeglichen (sonst wird bei der ersten Ausgabe eine 0000 als Messwert ausgegeben)
    subs r0, r0, #1                 // Verringere den Zaehler
    bne config_loop	           		// Wenn der Zaehler nicht null ist, wiederhole
	   
mainloop:
	bl	uart_charPresent			// wurde ein Zeichen eingegeben?			
	cmp r0, #0						// wenn ja, 
	bne check_input					// pruefen ansonsten gehe weiter
	
	ldr r0, [r9]					// Variable fuer Start/Stopp laden
	cmp	r0, #1						// laeuft die Messung?
	bne	mainloop					// nein, nur die Eingabe abfragen

	ldr r0, =str_hex				// Gebe eine fuehrende Null
	bl uart_putString				// fuer die Ausgabe einer Hex Zahl aus
	
	ldr r0, [r12, #RA]				// Lade was im Ergebnisregister steht in r0
	bl uart_putInt16				// Gebe aktuellen Wert des Potis auf das Terminal aus
	
	mov r0, #SP						// Lade Leerzeichen Konstante in r0
	bl uart_putChar					// Gebe ein Leerzeichen aus

	// Lade Maximalwert und Wert der Genauigkeit fuer nachfolgende Berechnungen
	ldr r4, =UPPER_LIMIT			// Lade den Maximalwert (3.3V = 3300mV)	
	ldr r5, [r8]					// Lade Wert, der der aktuellen Genauigkeit entspricht (aus mode Variable)
	 
/* 
 * Berechnung der aktuellen Stufe mit der Formel: aktueller ((aktueller Messwert) * (aktueller Genauigkeit)) / (2^Genauigkeit).
 * Dadurch erhalten wir immer die aktuelle Stufe in Abhaengigkeit von der aktuell eingestellten
 * Genauigkeit. 
 */	
	ldr r0, [r12, #RA]				// Lade den aktuellen Inhalt des Ergebnisregisters (aktueller Messwert) des ADC1
	mul r1, r0, r5					// (aktueller Messwert) * (aktueller Genauigkeit)
	lsr r6, r1, r5					// Teile dies nun durch 2^Genauigkeit (durch rechts shift) und lege Ergebnis in r6 ab
	
/* 
 * Berechnung der unteren Bereichsgrenze mit der Formel: (Maximalwert(3.3V)*aktuelle Stufe) / Genauigkeit.
 * Hier verwenden wir den im Schaltplan angegebenen Maximalwert von 3.3V = 3300mV und rechnen dann die 
 * untere Bereichsgrenze aus.
 */						
	mul r1, r4, r6					// Maximalwert(3.3V)*aktuelle Stufe
	udiv r0, r1, r5					// Dividiere dieses Ergebnis durch die aktuelle Genauigkeit und
	
	bl print_dec					// drucke anschliessend die untere Bereichsgrenze
	
	ldr r0, =str_line_and_sp		// Lade und 
	bl uart_putString				// drucke Leerzeichen und Dash

/* 
 * Berechnung der oberen Bereichsgrenze mit der Formel: (Maximalwert(3.3V)*(aktuelle Stufe + 1)) / Genauigkeit.
 * Hier verwenden wir den im Schaltplan angegebenen Maximalwert von 3.3V = 3300mV und rechnen dann die 
 * untere Bereichsgrenze aus.
 */	
	add r1, r6, #1					// aktuelle Stufe + 1
	mul r2, r4, r1					// (Maximalwert(3.3V)*(aktuelle Stufe + 1)
	udiv r0, r2, r5					// Dividiere dieses Ergebnis durch die aktuelle Genauigkeit und
		
	bl print_dec					// drucke anschliessend die obere Bereichsgrenze 
	
	ldr r0, =str_mv_and_sp			// Lade und 
	bl uart_putString				// drucke String fuer die Terminalausgabe
	
	ldr r0, =str_br_and_step		// Lade und
	bl uart_putString				// drucke String fuer die Terminalausgabe
	
	mov r0, r6						// Lade und 
	bl uart_putByteBase10			// drucke die aktuelle Stufennummer
	
	ldr r0, =str_close_and_lf		// Lade und
	bl uart_putString				// drucke String fuer die Terminalausgabe
	
	// Ausgabe der aktuellen Stufe auf den LEDs E1 bis E4
	ldr r0, =E1						// Bit-Band-Alias-Adresse der LED E1 laden
	bic r2, r7, r6					// R2 = R7 AND NOT R6; Bit 0 der aktuellen Stufe (R6) invertiert nach R2 schreiben 
	str r2, [r0]					// Bit auf LED ausgeben

	ldr r0, =E2
	bic r2, r7, r6, lsr #1			// R2 = R7 AND NOT (R6 >> 1); R6 wird zuerst um Eins nach rechts geschoben, 
	str r2, [r0]					// so dass effektiv Bit 1 der aktuellen Stufe verarbeitet wird

	ldr r0, =E3
	bic r2, r7, r6, lsr #2			// R2 = R7 AND NOT (R6 >> 2); Bit 2 von R6
	str r2, [r0]

	ldr r0, =E4
	bic r2, r7, r6, lsr #3			// R2 = R7 AND NOT (R6 >> 3); Bit 3 von R6
	str r2, [r0]
	
poll_loop:
	ldrb r0, [r10]					// Flag laden
	cmp	r0, #1						// Benutzerflag = Eins? 
	bne	poll_loop					// Nein -> weiter warten
	mov r0, #0
	strb r0, [r10]					// Benutzerflag zuruecksetzen
			
	b mainloop
	
check_input:
	bl	uart_getChar				// eingegebenes Zeichen einlesen
	cmp	r0, #CHAR_S					// war es ein 's'?
	beq	ci_s						// ja, verzweigen
	 
	ldrb r1, [r9]					// Variable fuer Start/Stopp laden
	cmp r1, #1						// mit eins (= Messung laeuft) vergleichen	
	beq mainloop					// laeuft die Messung so springe zurueck und ignoriere Eingabe

    cmp r0, #CHAR_0					// war es eine '0'?
    beq case_0						// ja, verzweigen

    cmp r0, #CHAR_1					// war es eine '1'?
    beq case_1						// ja, verzweigen

    cmp r0, #CHAR_2					// war es eine '2'?
    beq case_2						// ja, verzweigen

    cmp r0, #CHAR_3					// war es eine '3'?
    beq case_3						// ja, verzweigen
    
    b mainloop						// war es was anderes, kehre zurueck

case_0:
    mov r1, #CFG1_MODE_8			// war die Eingabe eine '0', so lade r1 und r4 entsprechend,
    mov r4, #8						// sodass das Umschalten auf 8 Bit Wandlung eingeleitet ist
    b switch_con					// Springe zum Umschalten

case_1:
    mov r1, #CFG1_MODE_10			// war die Eingabe eine '1', so lade r1 und r4 entsprechend,
    mov r4, #10						// sodass das Umschalten auf 10 Bit Wandlung eingeleitet ist
    b switch_con					// Springe zum Umschalten

case_2:
    mov r1, #CFG1_MODE_12			// war die Eingabe eine '2', so lade r1 und r4 entsprechend,
    mov r4, #12						// sodass das Umschalten auf 12 Bit Wandlung eingeleitet ist
    b switch_con					// Springe zum Umschalten

case_3:
    mov r1, #CFG1_MODE_16			// war die Eingabe eine '3', so lade r1 und r4 entsprechend,
    mov r4, #16						// sodass das Umschalten auf 16 Bit Wandlung eingeleitet ist, gehe ueber zum Umschalten

switch_con:
    // Re - Konfiguration von CFG1
    ldr r0, [r12, #CFG1]			// Lade Inhalt des CFG1 Registers in r0
    bic r0, r0, #BIT_MASK32			// Cleare die Bits, die wir setzen wollen (Bits 3-2)
    orr r0, r0, r1					// Setze die gewuenschten Bits
    str r0, [r12, #CFG1]			// Schreibe den Wert zurueck in das CFG1 register

    // Drucke ersten Teil einer Meldung ueber die Aenderung an den Nutzer
    ldr r0, =str_change1
    bl uart_putString

    // Aendere die mode Variable zur Darstellung entsprechend viele Stufen
    mov r0, r4
    str r0, [r8]
    
    // Drucke aktuellen Wandlungsmodus
    bl uart_putByteBase10
    
    // Drucke zweiten Teil einer Meldung ueber die Aenderung an den Nutzer
    ldr r0, =str_change2
    bl uart_putString
    
    b mainloop
	
ci_s:
	ldrb r1, [r9]					// Variable fuer Start/Stopp laden
	cmp r1, #1						// mit eins (= Messung laeuft) vergleichen						
	ittee ne						// Bedingung vorgeben
	ldrne r0, =str_start			// entsprechenden String auswaehlen
	ldrne r2, =SC1A_INIT_VAL
	ldreq r0, =str_stopp
	ldreq r2, =SC1A_STOP_VAL
	eor r1, r1, #1					// Variable umkehren
	str r1, [r9]					// und zurueckschreiben
	ldr r1, [r12] 
    bic r1, r1, #BIT_MASK40			// Cleare die Bits, die wir setzen wollen (bits 4-0) im SC1A Register
    orr r1, r1, r2					// Setze die gewuenschten Bits 
    str r1, [r12]					// Schreibe den Wert zurueck in das SC1A register
	bl	uart_putString				// gewaehlten String ausgeben

	ldrb r0, [r11]					// Schalte den PIT1 aus (beim Stoppen) beziehungsweise
	eor r0, r0, #1					// an (beim Starten), so wird die Ausgabe regelmaessiger,	
	strb r0, [r11]					// falls die Messung angehalten wurde

	b 	mainloop					// zurueck zum Anfang

/*
 * Gibt eine vierstellige Dezimalzahl auf das Terminal aus. Es wird zunaechst die Tausenderstelle
 * ausgegeben, dann die Hunderterstelle, die Zehnerstelle und schliesslich der Rest. So kann sicher-
 * gestellt werden, dass immer genug Zahlen (zum Beispiel auch fuehrende Nullen) ausgegeben werden.
 * Parameter: in r0 wird die Zahl uebergeben, die gedruckt werden soll
 * Rueckgabe: keine
 */	
.thumb_func
print_dec:
    push {r4, lr} 				// Sichere verwendete Register und den Rueckkehrpunkt
	mov r4, r0					// Zwischenspeichern der uebergebenen Zahl (aktueller Wert)
	
	mov r1, #1000    			// Berechnen der Tausenderstelle
	udiv r0, r4, r1  			// Isoliere Tausenderstelle und lege sie in r0 ab
	mul r2, r0, r1				// Tausenderstelle * 1000 und 
	sub r4, r4, r2				// aktueller Wert - dem Zwischenergebnis (entferne Tausenderstelle)
	bl uart_putByteBase10		// Drucke die Tausenderstelle
	
	mov r1, #100    			// Berechnen der Hunderterstelle
	udiv r0, r4, r1				// Isoliere Hunderterstelle und lege sie in r0 ab  		
	mul r2, r0, r1				// Hunderterstelle * 100 und
	sub r4, r4, r2				// aktueller Wert - dem Zwischenergebnis (entferne Hunderterstelle)
	bl uart_putByteBase10		// Drucke die Hunderterstelle
	
	mov r1, #10    				// Berechnen der Zehnerstelle
	udiv r0, r4, r1 			// Isoliere Zehnerstelle und lege sie in r0 ab
	mul r2, r0, r1				// Zehnerstelle * 10 und
	sub r4, r4, r2				// aktueller Wert - dem Zwischenergebnis (entferne Zehnerstelle)
	bl uart_putByteBase10		// Drucke die Zehnerstelle
	
	mov r0, r4
	bl uart_putByteBase10 		// Drucke die Einerstelle (bleibt am Ende uebrig)

    pop {r4, pc} 				// Stelle die Register wieder her und kehre zurueck
    
/*
 * Kalibiert den ADC nach Vorgaben des Handbuches. Dazu wird zunaechst die Kalibrierung intialisiert.
 * Dann wird solange immer wieder das COCO Bit des SC1A Registers ueberprueft bis die Kalibrierung
 * abgeschlossen ist. Ist diese fehlgeschlagen, so wird zur Fehlerbehandlung gesprungen. Sonst wird
 * nach den Vorgaben des Handbuches das PG Register mit entsprechender Summe beschrieben. Zu erwaehnen
 * bleibt, dass nur das PG Register beschrieben wird, da es sich hier um eine single ended Konvertierung
 * handelt und das MG Register deshalb ignoriert wird.
 * Parameter: keine
 * Rueckgabe: keine
 */	
.thumb_func
adc_cal:
	ldr r0, =ADC1_SC1A
	
	// Initialisiere die Kalibrierung (ADTRG Bit wird nicht ueberprueft, da in der Konfiguration auf 0 gesetzt)
	ldr r1, [r0, #SC3]				// Lade Inhalt von SC3 in r1
	orr r1, r1, #BIT_MASK7			// Bitposition des CAL Bits im SC3 Register
	str r1, [r0, #SC3]				// Setze das CAL Bit in SC3, um Kalibrierung zu starten
		
	// Warte bis die Kalibrierung fertig ist
wait_cal:
	ldr r1, [r0]					// Lade Inhalt von SC1A in r1
	tst r1, #BIT_MASK7				// Bitposition des COCO Bits im SC1A Register
	beq wait_cal					// Kehre so lange zurueck bis das COCO Bit gecleart wird
	
	// Pruefe, ob die Kalibrierung fehlgeschlagen ist
	ldr r1, [r0, #SC3]				// Lade Inhalt von SC3 in r1
	tst r1, #BIT_MASK6				// Bitposition des CALF Bits im SC3 Register
	bne fail_cal					// Ist das CALF Bit gesetzt, ist Kalibrierung fehlgeschlagen, springe entsprechend
	
	// Addiere positive Kalibrierungsergebnisse (es werden nur diese benoetigt wegen der single ended Konvertierung)
    ldr r1, [r0, #CLP0]			
    ldr r2, [r0, #CLP1]
    add r1, r1, r2
    ldr r2, [r0, #CLP2]
    add r1, r1, r2
    ldr r2, [r0, #CLP3]
    add r1, r1, r2
    ldr r2, [r0, #CLP4]
    add r1, r1, r2
    ldr r2, [r0, #CLPS]
    add r1, r1, r2

    mov r2, #1					// Teile schliesslich  
    lsr r1, r1, #1				// durch 2 und
    orr r1, r1, r2, lsl #15		// setze MSB (hier das 15. Bit wegen Halbwortlaenge)
    str r1, [r0, #PG]			// Speichere Ergebnis der Berechnung wie gefordert in PG zurueck

    bx lr         	 	 	 	// Kalibrierung erfolgreich kehre zurueck
	
fail_cal:						// Kalibrierung fehlgeschlagen kehre zurueck und/oder fuege entsprechende Aktion ein
	ldr r0, =str_cal_fail
	bl uart_putString
	
	ldr r0, =cal_failed			// Lade Adresse des Kalibrierung fehlgeschlagen Flags
	mov r1, #1					// und setze dieses Flag auf 1, um eine
	str r1, [r0]				// fehlgeschlagene Kalibrierung zu signalisieren

	bx lr						// Springe zurueck
		
/*
 * Initialisiert die GPIO Ports und zugehoerige Module fuer die LED Anzeige
 * Parameter: keine
 * Rueckgabe: keine
 */		
.thumb_func
gpio_leds_init:
// Takt fuer die benutzten Module aktivieren
	ldr r0, =SIM_PORTA
	mov r1, #1
	str r1, [r0]
	
// Adressierung der Konfigurations-Register mit Offset
	ldr r0, =PORTA_PCR0 		// Startadresse der Port A PCR-Register
 
	mov r1, #GPIO_SET 			// GPIO-Modus festlegen
 	str r1, [r0, #PCR11]		// E1
 	str r1, [r0, #PCR28]		// E2
 	str r1, [r0, #PCR29]		// E3
 	str r1, [r0, #PCR10]		// E4
	
// Datenrichtung der GPIO-Pins festlegen - Ausgaenge (LEDs)
	ldr r0, =GPIOA_PDDR
	ldr r1, =PDDR_MASK_LED
	ldr r2, [r0]
	orr	r2, r2, r1
	str r2, [r0]
 	bx lr

/*
 * Initialisiert den PIT1
 * Parameter: keine
 * Rueckgabe: keine
 */		
.thumb_func
pit1_init:
	ldr r0, =SCR_VTOR				// Basisadresse der IVT
	ldr r1, [r0]					// laden
	ldr r0, =isr_pit1				// ISR fuer den PIT1 
	str r0, [r1, #PIT1_IRQ_OFS]		// in die IVT eintragen
	
	ldr r0, =NVIC_ICPR2				// Pending (haengende) IRQs zu PIT1 im NVIC loeschen
	mov r1, #PIT1_NVIC_MASK			// Bit für PIT1-IRQ in den NVIC-Registern
	str r1, [r0]
	ldr r0, =NVIC_ISER2				// IRQs zu PIT1 im NVIC aktivieren
	str r1, [r0]					// R1 hat noch den Wert (PIT1_NVIC_MASK), also nicht neu laden

	ldr r0, =SIM_PIT				// Bit-Band-Alias-Adresse fuer das Bit des PIT im SIM laden
	mov r1, #1						
	str r1, [r0]					// Clock fuer PIT1 aktivieren
	ldr r0, =PIT_MCR				
	mov r1, #PIT_MCR_VAL			// alle PITs einschalten, im Debug-Modus anhalten
	str r1, [r0]
	ldr r0, =PIT_LDVAL1				// initialen Zaehlwert setzen
	ldr r1, =PIT_COUNT 
	str r1, [r0]
	ldr r0, =PIT_TCTRL1
	mov r1, #PIT_TCTRL1_VAL			// PIT1: aktivieren, IRQs aktiv 
	str r1, [r0]
	
 	bx lr

/*
 * PIT1-ISR (Interrupt Service Routine)
 * Parameter: keine Parameter moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 * Rueckgabe: keine Rueckgabe moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 */		
.thumb_func
isr_pit1:
	mov r1, #0x1
	ldr r0, =pit1_flag				// Benutzerflag setzen
	str r1, [r0]
	ldr r0, =PIT_TFLG1				// TIF (Timer Interrupt Flag) loeschen
	str r1, [r0]
	
	bx lr

/*** Datenbereich (ab 0x20000000) ***/
.data
running: .word 1					// 1: Messung laeuft, 0: Uhr Messung ist angehalten
pit1_flag: .word 0
mode: .word 16
cal_failed: .word 0
str_hex: .asciz "0x"
str_cal_fail: .asciz "Kalibrierung fehlgeschlagen. Sollte dies wiederholt auftreten, muss das Programm manuell beendet werden!\n"
str_line_and_sp: .asciz " - "
str_mv_and_sp: .asciz " mV "
str_br_and_step: .asciz "(Stufe "
str_close_and_lf: .asciz ")\n"
str_start: .asciz "Messung gestartet.\n"
str_stopp: .asciz "Messung angehalten.\n"
str_change1: .asciz "Die Konvertierung wurde geaendert. Es wird nun mit "
str_change2: .asciz " Bit Genauigkeit gewandelt.\n"
