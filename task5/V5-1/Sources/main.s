/************************************************************
Versuch: 5-1
Name: Philip Redecker 
Matrikel-Nr.: 3257525 
Zeitbedarf: 45 Stunden
************************************************************/

/*********************************************************************************************************
Beobachtungen zu Aufgabenteil c)

Wenn die gemessene Temperatur irgendwann die in TOS eingelesene Temperatur (T_0 + 3) ueberschreitet,
dann leuchtet eine LED orange, die sich auf der gruenen Platine befindet. Wenn nun anschliessend die 
Temperatur aus THYST (T_0 + 2) irgendwann unterschritten wird, so geht die orange LED wieder aus. Dies
entspricht auch der Erwartung, wenn man den Erklaerungen auf Seite 8 (DS75 Handbuch) zum Komparator Modus
folgt. 
**********************************************************************************************************/

// Include-Dateien
.include "k1514.inc"			// Praktikumsspezifische Definitionen
.include "lib_pit.inc"			// Einfache Unterprogramme zur Zeitmessung
.include "lib_uart.inc"			// Unterprogramme zur Ein-/Ausgabe vom/zum Terminal (CuteCom)

// Assemblerdirektiven
.text							// hier beginnt ein Code-Segment
.align	2						// Ausrichtung an eine gerade Adresse
.global	main					// "main" wird als globales Symbol deklariert
.syntax unified

// Konstanten fuer den PIT (Erzeugung einer Verzoegerung von einer Sekunde)
.equ SIM_SCGC6,	 	0x4004803C
.equ SCR_VTOR,		0xE000ED08		// Register für die Interrupt-Vektor-Tabelle (IVT)
.equ PIT_MCR,       0x40037000
.equ PIT_LDVAL1,    0x40037110
.equ PIT_TCTRL1,    0x40037118
.equ PIT_TFLG1,     0x4003711C
.equ NVIC_ISER2, 	0xe000e108
.equ NVIC_ICPR2, 	0xe000e288

__BBREG BB_SIM_PIT, SIM_SCGC6, 23	// Bit-Band-Alias-Adresse für den PIT im SIM-Register

.equ PIT1_IRQ_OFS,	0x154			// Interrupt Request Offset für PIT1
.equ PIT1_NVIC_MASK, 1 << (69 % 32)	// Bitposition für PIT-IRQ in NVIC-Registern (IRQ mod 32)
.equ PIT_COUNT, 25000000-1			// 25000000	Takte bei 25 MHz => 1 Sekunde
.equ PIT_MCR_VAL, 0					// MDIS = 0, FRZ = 0
.equ PIT_TCTRL1_VAL, 3				// CHN = 0, TIE = 1, TEN = 1

// Konstanten fuer den I2C Bus (Reset)
.equ SIM_SCGC5, 0x40048038			// Adresse des SIM Registers mit dem Port D (hier ist das Thermometer angeschlossen) initialisiert werden kann
.equ GPIOD_PDOR, 0x400ff0c0			
.equ GPIOD_PDIR, 0x400ff0d0			
.equ GPIOD_PDDR, 0x400ff0d4			
.equ PORTD_PCR8, 0x4004c020			
.equ PORTD_PCR9, 0x4004c024			
.equ PD8_9, 0x300	 				// Maske fuer PD8 und PD9
.equ PD8, 0x100 					// Maske fuer PD8
.equ ALT1_GPIO, 0x100 				// Alternative 1: GPIO
.equ ALT2_GPIO, 0x200 				// Alternative 2: I2C (siehe Tabelle K60 Handbuch Seite 248)
__BBREG SIM_PORTD, SIM_SCGC5, 12

// Konstanten fuer den I2C Bus (Konfiguration und Initialisierung)
.equ SIM_SCGC4, 0x40048034			// Adresse des SIM Registers mit dem das I2C0 Modul aktiviert werden kann
__BBREG SIM_I2C0, SIM_SCGC4, 6		// BBA des sechsten Bit von SIM_SCGC4 zur Aktivierung von I2C0

.equ I2C0_F,   	0x40066001			// Die Adresse des Registers des I2C0 Moduls fuer die Frequenzteilung
.equ I2C0_C1,  	0x40066002			// Die Adresse des ersten Kontrollregisters des I2C0 Moduls
.equ I2C0_S,   	0x40066003			// Die Adresse des Statusregisters des I2C0 Moduls
.equ I2C0_D,   	0x40066004			// Die Adresse des Dateninput/-output - Registers des I2C0 Moduls

.equ I2C0_F_INIT400,  0x49			// MULT = 0x01 und ICR = 0x09 => 0100 1001 => SCL Divider fuer 9 ist 32 und dadruch erhalten wir 25000 / (2 * 32) ist ca 391kHz
.equ I2C0_C1_INIT,	  0xc0			// Konstante fuer die Initialbelegung vom C1 Register, es werden die Bits fuer Aktivierung und Interrupts gesetzt

__BBREG I2C0_C1_MST, I2C0_C1, 5		// Konstante fuer die BBA vom Master Mode Select Bit des I2C0 Kontrollregisters (C1)
__BBREG I2C0_C1_TX, I2C0_C1, 4		// Konstante fuer die BBA vom Transmit Mode Select Bit des I2C0 Kontrollregisters (C1)
__BBREG I2C0_C1_TXAK, I2C0_C1, 3	// Konstante fuer die BBA vom Transmit Ackknowledge Bit des I2C0 Kontrollregisters (C1)
__BBREG I2C0_C1_RSTA, I2C0_C1, 2	// Konstante fuer die BBA vom Repeat Start Bit des I2C0 Kontrollregisters (C1)

__BBREG I2C0_S_IICIF, I2C0_S, 1		// Konstante fuer die BBA vom Interrupt Bit des I2C0 Statusregisters (S) - fuer die Behandlung von ACK/NACK im I2C Protokoll
__BBREG I2C0_S_BUSY, I2C0_S, 5		// Konstante fuer die BBA vom BUSY Flag im Statusregiser - fuer die Pruefung, ob der Bus zugeteilt wurde (Start-Bedingung)

// Konstanten fuer das Thermometer DS75
.equ DS75_R, 0x91					// Adresse des Registers im DS75, das fuer das Lesen zustaendig ist
.equ DS75_W, 0x90					// Adresse des Registers im DS75, das fuer das Schreiben zustaendig ist
.equ DS75_CONFIG, 0x60				// Konstante fuer die Konfiguration des DS75 0110 0000 => Aufloesung 12 Bit, Komparator Modus, aktive Konvertierung

// Konstanten fuer Zeiger
.equ DS75_TEMP,  0x00				// Konstante fuer einen Zeiger auf das Temperaturregister (gemessene Temperatur) des DS75
.equ DS75_CON_ADR, 	 0x01			// Konstante fuer einen Zeiger auf das Konfigurationsregister des DS75
.equ DS75_THYST, 0x02				// Konstante fuer einen Zeiger auf das THYST Register des DS75
.equ DS75_TOS, 	 0x03				// Konstante fuer einen Zeiger auf das TOS Register des DS75

// weitere, allgemeine Konstanten
.equ I2C_DELAY_TIME, 125			// 125 Takte Wartezeit entspricht ca 5 us - um auf der sicheren Seite zu sein wird etwas laenger als 2 us gewartet
.equ WAIT_I2C_IICIF_FLAG, 1000		// Die Anzahl der Takte die auf das IICIF Flag gewartet wird. So wird eine Abbruchbedingung erzeugt (Vermeidung einer pot. Endlosschleife)
.equ COUNTER_LOOP, 10				// Zaehler fuer Reset und Start Unterprogramme
.equ POST_COMMA_MASK, 0xf000		// Bitmaske, um das MSB waehrend des Programmes zu isolieren
.equ ERROR_CODE, 0xff				// Ein Byte, dass einen Fehler im Programmverlauf anzeigt und es ermoeglicht das Programm zu beenden (Wechsel in end-Schleife)
.equ LF, 0x0A						// Line Feed
.equ SPACE, ' '
.equ COMMA, ','
.equ COLON, ':'

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init					// Initialisiere UART 
	
	bl I2CBus_Reset					// Setze I2C Bus zurueck
	
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm I2CBus_Reset ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// im Reset des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden

/*
 * ************************* Register vorbelegen ***************************
 */	
	
	ldr r12, =pit_flag				// Adresse des Benutzerflags laden
	ldr r11, =I2C0_D				// Adresse des Datenregisters des I2C0 Moduls
	
/*
 * ***************** I2C - Bus konfigurieren / initialisieren *******************
 */
	ldr r0, =SIM_I2C0 				// Den Takt fuer das I2C0 Modul aktivieren
	mov r1, #1
	str r1, [r0]
	
	ldr r0, =I2C0_F 				// Die Bus Baud Rate einstellen mit vorher angelegtem Wert
	mov r1, #I2C0_F_INIT400			// Die maximal moegliche Geschwindigkeit ist nach Handbuch 400kHz und
	strb r1, [r0]					// deshalb wurde dieser Wert gewaehlt (Rechnung siehe oben)
	
	ldr r0, =I2C0_C1 				// Das I2C0 Modul und deren Interrupts aktivieren, es werden in
	mov r1, #I2C0_C1_INIT			// Kontrollregister 1 das IICEN und das IICIE Bit gesetzt. Alle anderen 
	strb r1, [r0]					// Bits werden mit 0 voreingestellt

	bl start_I2C_con				// Start-Bedingung (starte Konfiguration, Schreiben der gewuenschten Konfig fuer DS75)
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm start_I2C_con ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Zuteilung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
						
	mov r0, #DS75_W					// Adresse zum Schreiben (0x90) nach I2C0_D schreiben
	strb r0, [r11]

    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
					
    mov r0, #DS75_CON_ADR			// Adresse des Konfigurationsregsters (0x01) in I2C0_D schreiben
	strb r0, [r11]	
	 
    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
    					
    mov r0, #DS75_CONFIG			// Die gewuenschte Konfig nach I2C0_D schreiben und damit ins Konfigurations-	
	strb r0, [r11]					// register des DS75 schreiben
	
    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
    
    bl stop_I2C_con					// Stopsignal erzeugen
    
/*
 * ***************** Rest initialisieren (PIT, OS und HYST) *******************
 */

    bl read_from_ds75				// Auslesen des Thermometers zur Initialisierung von TOS und THYST

	lsr r1, r0, #16					// Isolieren Vorkomma Byte (MSB) durch Schieben nach rechts, zwischenspeichern in r4 (T_0)
	add r4, r1, #3					// Addiere 3 zu T_0 und Zwischenspeichern von T_0 + 3 in r4
	add r5, r1, #2					// Addiere 2 zu T_0 und Zwischenspeichern von T_0 + 2 in r5
	and r1, r0, #POST_COMMA_MASK	// Nachkomma Halb-Byte (LSB) isolieren (Die Zahl wird insgesamt im 12 Bit Format xxxxxxxx.xxxx uebergeben)
	lsr r6, r1, #8					// es reicht also die Bits 15, 14, 13 und 12 zu betrachten. Zwischenspeichern in r6
		
	bl start_I2C_con				// Startsignal erzeugen (zum Schreiben in das TOS Register)
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm start_I2C_con ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Zuteilung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
						
	mov r0, #DS75_W					// Adresse zum Schreiben (0x90) nach I2C0_D schreiben
	strb r0, [r11]

    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden			
							
    mov r0, #DS75_TOS				// Zeiger (0x03) ins Register I2C0_D schreiben, um Pointer auf TOS Register zu setzen
	strb r0, [r11]
	
	bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
					
	strb r4, [r11]					// MSB von T_0 + 3 nach I2C0_D und damit in TOS schreiben
	
	bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
						
	strb r6, [r11]					// LSB von (T_0 + 3) nach I2C0_D und damit in TOS schreiben
	
	bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
	
	bl stop_I2C_con					// Stopsignal erzeugen
	
	bl start_I2C_con				// Startsignal erzeugen (zum Schreiben in das THYST Register)
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm start_I2C_con ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Zuteilung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
						
	mov r0, #DS75_W					// Adresse (0x90 zum Schreiben) nach I2C0_D schreiben
	strb r0, [r11]

    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
							
    mov r0, #DS75_THYST				// Pointer (0x02) im Register I2C0_D schreiben, um Pointer auf THYST Register zu setzen
	strb r0, [r11]

	bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
					
	strb r5, [r11]					// MSB von T_0 + 2 nach I2C0_D und damit nach THYST schreiben

	bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
		
    ldr r0, =I2C0_C1_TXAK			// TXAK auf 1 setzen (vor der letzten Uebertragung in der Initialisierung) 
	mov r1, #1						// So wird zuletzt ein NAK ausgegeben um das Ende der Uebertragung anzuzeigen
	strb r1, [r0]
	
	strb r6, [r11]					// LSB von T_0 + 2 nach I2C0_D und damit nach THYST schreiben
	
	bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
	
	bl stop_I2C_con					// Stopsignal erzeugen
 
	bl pit1_init					// PIT1 initialisieren

/*
 * Hier beginnt das Hauptprogramm. Im main_loop wird jede Sekunde (durch PIT erzeugt) immer eine Temperatur
 * aus dem DS75 ausgelesen und mit entsprechenden Strings wird eine Terminalausgabe erzeugt. Anschliessend
 * wird auf das Setzen des PIT Flags gewartet (poll_loop).
 */	
main_loop:
	ldr r0, =str_hex_prefix
	bl uart_putString
	
	bl read_from_ds75				// Auslesen des Thermometers
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm read_from_ds75 ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq end							// in einem der genutzten Unterprogramme an. Springe zu end, das Programm muss (manuell) neu gestartet werden
	
	mov r4, r0						// Zwischenspeichern des aktuellen Temperaturwertes
	
	bl uart_putInt32				// Aktueller Wert steht noch in r0 -> Gebe den Wert aus!
	
	mov r0, #COLON					// Gebe ein Semikolon aus
	bl uart_putChar
		
	mov r0, #SPACE					// Gebe ein Leerzeichen aus
	bl uart_putChar
	
	lsr r0, r4, #16					// Isolieren Vorkomma Byte durch Schieben nach rechts
	bl out_leading0					// Ausgabe der Zahl vor dem Komma
	
	mov r0, #COMMA					// Gebe ein Komma aus
	bl uart_putChar
	
	and r0, r4, #POST_COMMA_MASK	// Nachkomma Halb-Byte isolieren (Die Zahl wird insgesamt im 12 Bit Format xxxxxxxx.xxxx uebergeben)
	lsr r0, r0, #12					// es reicht also die Bits 15, 14, 13 und 12 zu betrachten. Schiebe diese an LSB Position
		
	mov r1, #100					// Umrechnen der Nachkommastelle         
    mul r0, r0, r1        			// Erst Multiplizieren wir mit 100 
    mov r1, #16         			// und dann teilen wir durch 16 (HEX Format)
    udiv r0, r0, r1					// und erhalten so die entsprechende Nachkommazahl im Hex Format
    bl out_leading0					// Ausgabe der Zahl nach dem Komma     
	
	ldr r0, =str_grad				// Gebe Grad Celsius String aus
	bl uart_putString

poll_loop:
	ldrb r0, [r12]					// Flag laden
	cmp	r0, #1						// Benutzerflag = Eins? 
	bne	poll_loop					// Nein -> weiter warten
	mov r1, #0						// Defaultwert für das Benutzerflag
	strb r1, [r12]					// Benutzerflag zuruecksetzen	
	b 	main_loop					// zurueck zum mainloop
	
end:
	b end
	
/*
 * Ein UP zum Starten einer I2C Uebertragung. Es wird das TX Bit auf transmit eingestellt, denn
 * es muss hier immer erstmal uebertragen werden. Dann setzen wir das TXAK-Flag auf 0, um so das
 * SCL Signal hoch zu schalten und das Senden von ACKs zu ermoeglichen. Schliesslich wird noch
 * Das MST Bit gesetzt, denn wenn dies von 0 auf 1 geaendert wird, wird ein Startsignal erzeugt.
 * Dies wird so lange wiederholt bis das BUSY Bit im Statusregister gesetzt ist. Schlaegt die 
 * Zuteilung des Busses fehl, wird ein Fehlercode zurueckgegeben.
 *
 * Parameter: keine
 * Rueckgabe: In r0 wird ein Fehlercode zurueckgegeben, falls die Buszuteilung fehlschlaegt.
 */	
.thumb_func
start_I2C_con:
	push {lr}
	ldr r0, =I2C0_S_BUSY			// Lade die BBA des BUSY Flags des I2C0 Statusregisters
	mov r1, #COUNTER_LOOP			// Lade einen Zaehlwert
	
start:
    ldr r2, =I2C0_C1_TXAK			// TXAK-Flag auf 0 setzen
	mov r3, #0
	strb r3, [r2]

	ldr r2, =I2C0_C1_TX				// TX auf 1 setzen
	mov r3, #1
	strb r3, [r2]

	ldr r2, =I2C0_C1_MST			// MST auf 1 setzen
	strb r3, [r2]
	
	ldrb r2, [r0]					// Hier wird geprueft, ob das BUSY Flag gesetzt ist,
	cmp r2, #1						// ob also der Bus zugeteilt wurde.
	beq end_start					// Ist das BUSY Bit gesetzt, springe zum Ende und somit zurueck
	subs r1, r1, #1					// Ist das BUSY Bit noch nicht gesetzt, dekrementiere Zaehler
	bne start						// und springe zurueck zum Anfang
		
	ldr r0, =str_asign_fail			// Nach 10 Versuchen wird ein String ausgegeben der einen Fehler
	bl uart_putString				// anzeigt und eine 1 zurueckgegeben als Fehlercode zur Weiter-
	mov r0, #ERROR_CODE			    // verarbeitung
	
end_start:
	pop {pc}						// Springe zurueck
	
/*
 * Ein UP zum Stoppen einer I2C Uebertragung. Dazu wird das MST Bit des Kontrollregisters C1
 * von 1 auf 0 gesetzt.
 *
 * Parameter: keine
 * Rueckgabe: keine
 */	
.thumb_func
stop_I2C_con:
	push {lr}						
	ldr r0, =I2C0_C1_MST			// Lade BBA vom MST Bit des Kontrollregisters
	mov r1, #0						// und setze dieses von 1 auf 0, so wird ein 
	strb r1, [r0]					// STOP Signal erzeugt.	
	bl i2c_Delay					// Warte 5 us, um zu gewaehrleiten, dass Busleitungen ihren Ruhezustand einnehmen.	
	pop {pc}
	
/*
 * Ein UP zum wiederholten Starten einer I2C Uebertragung. Dazu wird das RSTA Bit des
 * Kontrollregisters C1 gesetzt.
 *
 * Parameter: keine
 * Rueckgabe: keine
 */	
.thumb_func
repeat_I2C_con:
	ldr r0, =I2C0_C1_RSTA			// Lade BBA des RSTA Bit des Kontrollregisters C1
	mov r1, #1						// und setze dieses Bit. Dies erzeugt ein REPEAT-START
	strb r1, [r0]					// Signal
	bx lr							// Springe zurueck
	
/*
 * Ein UP zum Warten auf das IICIF Flag. In diesem UP wird auch das IICIF Flag zurueckgesetzt.
 * Es wird fuer 1000 Takte gewartet und wenn das Flag nach dieser Wartezeit nicht gesetzt wird,
 * wird ein Fehlercode in r0 zurueckgegeben. Wird das Flag nicht gesetzt, ist eine Transaktion nicht
 * nicht erfolgreich gewesen oder es wurde kein ACK gesendet.
 *
 * Parameter: keine
 * Rueckgabe: Bei erfolglosem Warten auf das IICIF Flag wird ein Fehlercode in r0 zurueckgegeben.
 */
.thumb_func
wait_I2C_flag:
	push {lr}
	mov r0, #WAIT_I2C_IICIF_FLAG	// Schreibe die Anzahl an Takten, die gewartet werden soll in r0 (1000, Erklaerung siehe oben)
	ldr r1, =I2C0_S_IICIF			// Schreibe die BBA des IICIF Flags in r1
	
wait:
	ldrb r2, [r1]					// Ueberpruefe, ob das IICIF Flag gesetzt wurde
	cmp r2, #1						// Wurde es gesetzt, so wird
	beq end_wait					// zu end_wait gesprungen, das IICIF Flag zurueckgesetzt und zurueckgesprungen
	subs r0, r0, #1					// Wurde es nicht gesetzt, dann dekrementiere Zaehler
	bne wait						// Ist der Zaehler noch nicht 0, so springe zurueck zu wait

	ldr r0, =str_con_fail			// Wenn das IICIF Flag nach 1000 Takten nicht gesetzt wurde, wird ein String ausgegeben 
	bl uart_putString				// der einen Fehler anzeigt und eine 1 zurueckgegeben als Fehlercode zur Weiter-
	mov r0, #ERROR_CODE				// verarbeitung
	
end_wait:
	mov r2, #1						// Setze das IICIF Flag zurueck, indem eine 1 an die
	strb r2, [r1]					// BBA des IICIF Flag geschrieben wird
	pop {pc}

/*
 * Ein UP zum Lesen der aktuell gemessenen Temperatur aus den Registern des DS75 Thermometers.
 *
 * Parameter: keine
 * Rueckgabe: In r0 wird die gemessene Temperatur zurueckgegeben.
 */	
.thumb_func
read_from_ds75:
	push {r4,r5,r6,lr}

	bl start_I2C_con				// Start-Bedingung (hier zum Auslesen der aktuell gemessenen Temperatur)
	cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm start_I2C_con ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq fail_read					// in der Zuteilung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden

	ldr r4, =I2C0_D					// Belege Register r4 mit Adresse von Datenregister vor, da es oft gebraucht wird
	
	mov r0, #DS75_W					// Adresse zum Schreiben (0x90) nach I2C0_D schreiben
	strb r0, [r4]

    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq fail_read					// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
				
    mov r0, #DS75_TEMP				// Die Adresse des Temperaturregisters (0x00) des DS75 in I2C0_D schreiben
	strb r0, [r4]

    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq fail_read					// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
    
    bl repeat_I2C_con				// Repeat_Start auslösen
				
    mov r0, #DS75_R					// Adresse zum Lesen (0x91) nach I2C0_D schreiben
	strb r0, [r4]

    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq fail_read					// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden

    ldr r0, =I2C0_C1_TX				// TX auf 0 setzen, stelle um auf Receive
	mov r1, #0
	strb r1, [r0]
				
    ldrb r0, [r4]					// ein Byte aus I2C0_D lesen, dummy read

    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq fail_read					// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
					
    ldrb r5, [r4]					// MSB der aktuell gemessenen Temperatur aus I2C0_D lesen

    ldr r0, =I2C0_C1_TXAK			// TXAK auf 1 setzen (vor der letzten Uebertragung) 
	mov r1, #1						// So wird zuletzt ein NAK ausgegeben um das Ende der Uebertragung anzuzeigen
	strb r1, [r0]
	
    bl wait_I2C_flag				// IICIF-Flag abwarten und IICIF zurücksetzen
    cmp r0, #ERROR_CODE				// Wird aus dem Unterprogramm wait_I2C_flag ein Fehlercode zurueckgegeben, zeigt dies einen Fehler
	beq fail_read					// in der Uebertragung des I2C Busses an. Springe zu end, das Programm muss (manuell) neu gestartet werden
    
    bl stop_I2C_con					// Stop-Bedingung auslösen
				
    ldrb r6, [r4]					// LSB der aktuell gemessenen Temperatur aus I2C0_D lesen, dieses steht erst nach der Stop-Bedingung zur Verfuegung 

    lsl r0, r5, #8					// danach MSB und LSB sichern (in gefordertem Format)
    orr r0, r0, r6					// also 00MSB.LSB00. Diese Messung wird dann in r0 zurueckgegeben
    lsl r0, r0, #8

fail_read:	
	pop {r4,r5,r6,pc}				// Stelle Register von Stack wieder her und springe zurueck
	
/*
 * Setzt den I2C Bus zurueck - Aufruf einmal zu Beginn des Programmes, um eine richtige
 * Initialisierung zu gewaehrleisten. Wenn die Initialisierung fehlschlaegt, so wird eine
 * Nachricht fuer den Nutzer ausgegeben und ein Fehlercode in r0 zurueckgegeben.
 *
 * Parameter: keine
 * Rueckgabe: In r0 wird ein Fehlercode zurueckgegeben, falls die Initialisierung fehlschlaegt.
 */	
.thumb_func
I2CBus_Reset:
	push {r4,lr}

	ldr r0, =SIM_PORTD 				// Den Takt fuer Port D aktivieren
	mov r1, #1
	str r1, [r0]
	ldr r0, =PORTD_PCR8 			// Portleitungen PD8 , PD9 als GPIO
	ldr r1, =PORTD_PCR9
	mov r2, #ALT1_GPIO
	str r2, [r0]
	str r2, [r1]
	ldr r0, =GPIOD_PDDR 			// PD8 , PD9 als Ausgang schalten
	ldr r2, [r0]
	orr r2, r2, #PD8_9
	str r2, [r0]
	
	mov r4, #COUNTER_LOOP
	
loop:
	ldr r0, =GPIOD_PDOR 			// SCL deaktivieren
	ldr r2, [r0]
	bic r2, r2, #PD8 				// entsprechendes Bit loeschen
	str r2, [r0]
	bl i2c_Delay
	
	ldr r0, =GPIOD_PDOR 			// SCL und SDA aktivieren
	ldr r2, [r0]
	orr r2, r2, #PD8_9
	str r2, [r0]
	bl i2c_Delay

	ldr r0, =GPIOD_PDIR
	ldr r2, [r0]
	and r2, r2, #PD8_9 				// nur Bits 9 und 10 pruefen
	cmp r2, #PD8_9	 				// Bit 9 und Bit 10 gesetzt ?
	beq end_reset 					// wenn ja springe zum Ende des Unterprogrammes

	subs r4, r4, #1  				// Wenn nein, subtrahiere 1 vom Zaehler in r4, setze Condition Flags entsprechend
    bne loop     					// Wenn Zaehler ungleich 0 ist, so springe zurueck zu loop und versuche Reset erneut

    ldr r0, =str_reset_fail			// Ist Zaehler gleich 0 und die Bits 9 und 10 waren nicht wie gewuenscht gesetzt, lade Adresse der Fehlermeldung
	bl uart_putString				// Gebe Fehlermeldung aus
	mov r0, #ERROR_CODE				// Gebe einen Fehlercode in r0 zurueck und
	b fail_reset					// Springe zum Ende des Unterprogrammes (der Rest der Fehlerbehandlung erfolgt dann im Hauptprogramm)
	
end_reset:
	ldr r0, =PORTD_PCR8 			// Reset erfolgreich. Stelle nun die Ports im Mux Bitfeld als Alternative 2 ein (Berieb mit I2C)
	ldr r1, =PORTD_PCR9				// Portleitungen PD8 , PD9 als GPIO
	mov r2, #ALT2_GPIO				// Lade Wert fuer Alternative 2
	str r2, [r0]
	str r2, [r1]
	
fail_reset:
	pop {r4,pc}						// Springe zurueck ins Hauptprogramm
	
/*
 * Ein UP i2c_Delay, dass 5 us wartet. 
 *
 * Parameter: keine
 * Rueckgabe: keine
 */
.thumb_func
i2c_Delay:
	ldr r0, =I2C_DELAY_TIME
	
count_loop:
	subs r0, r0, #1
	bne count_loop	
	bx lr

/*
 * Gibt bei Zahlen < 10 eine fuehrende Null aus
 *
 * Parameter: 8-bit-Zahl in R0
 * Rueckgabe: keine
 */		
.thumb_func
out_leading0:
	push {lr}
	cmp r0, #10						// >= 10? 
	ite hs
	ldrhs r1, =uart_putByteBase10	// ohne fuehrende Null
	ldrlo r1, =uart_putByte			// mit fuehrender Null
	blx r1							// entsprechendes UP aufrufen
	pop {pc}
	
/*
 * Initialisiert den PIT.
 *
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

	ldr r0, =BB_SIM_PIT				// Bit-Band-Alias-Adresse fuer das Bit des PIT im SIM laden
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
 * PIT-ISR (Interrupt Service Routine)
 *
 * Parameter: keine Parameter moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 * Rueckgabe: keine Rueckgabe moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 */		
.thumb_func
isr_pit1:
	mov r1, #0x1
	ldr r0, =pit_flag				// Benutzerflag setzen
	str r1, [r0]
	ldr r0, =PIT_TFLG1				// TIF (Timer Interrupt Flag) loeschen
	str r1, [r0]
	bx lr
		
/*** Datenbereich (ab 0x20000000) ***/
.data
pit_flag: .word 0
str_reset_fail: .asciz "Reset des I2C Busses ist fehlgeschlagen. Programm wird beendet.\n"
str_asign_fail: .asciz "Zuteilung des I2C Busses ist fehlgeschlagen. Programm wird beendet.\n"
str_con_fail: .asciz "Es ist ein Verbindungsfehler aufgetreten. Programm wird beendet.\n"
str_hex_prefix: .asciz "0x"
str_grad: .asciz " Grad Celsius \n"
