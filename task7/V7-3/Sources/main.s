/************************************************************
Versuch: 7-3
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

// Allgemeine Registeradressen
.equ SIM_SCGC5,     0x40048038
.equ SIM_SCGC6,	 	0x4004803C

// Allgemeine Adressen fuer die Interrupt Konfiguration
.equ SCR_VTOR,		0xE000ED08				// Register für die Interrupt-Vektor-Tabelle (IVT)

.equ NVIC_ISER1, 	0xE000E104
.equ NVIC_ICPR1, 	0xE000E284

// Register und Konstanen fuer Port A Intitialisierung
.equ GPIOA_PDOR,    0x400FF000
.equ GPIOA_PDDR,    0x400FF014
.equ PORTA_PCR0,	0x40049000		    	// Adresse der Port A PCR-Registers
.equ PDDR_MASK_FTM0, (1<<6)					// Maske fuer den Ausgang PTA6
.equ SET_FTM0, 0x300						// ALT3, Open Drain deaktiviert

// Bit Band-Konstanten
__BBREG	SIM_PORTA, SIM_SCGC5, 9
__BBREG	PTA6, GPIOA_PDOR, 6

// Offsets für die einzelnen PCR-Register
.equ PCR6,	0x18							// Offset fuer PTA6

// Register und Konstanten fuer FTM0
.equ FTM0_CONF, 	0x40038084				// Configuration (FTM0_CONF)
.equ FTM0_FMS,		0x40038074				// Fault Mode Status (FTM0_FMS)
.equ FTM0_MODE, 	0x40038054				// Features Mode Selection (FTM0_MODE) 
.equ FTM0_CNTIN, 	0x4003804C				// Counter Initial Value (FTM0_CNTIN)
.equ FTM0_MOD, 		0x40038008				// Modulo (FTM0_MOD)
.equ FTM0_C3SC,	 	0x40038024				// Channel (n) Status And Control (FTM0_C3SC) ------> Channel 3
.equ FTM0_COMBINE, 	0x40038064				// Function For Linked Channels (FTM0_COMBINE) 
.equ FTM0_DEADTIME, 0x40038068				// Deadtime Insertion Control (FTM0_DEADTIME)
.equ FTM0_C3V, 		0x40038028				// Channel (n) Value (FTM0_C3V) 
.equ FTM0_SC, 		0x40038000				// Status And Control (FTM0_SC)

.equ FTM0_SYNCONF, 	0x4003808C				// Synchronization Configuration (FTM0_SYNCONF) 
.equ FTM0_POL, 		0x40038070				// Channels Polarity (FTM0_POL)
.equ FTM0_SYNC, 	0x40038058				// Synchronization (FTM0_SYNC)

__BBREG BB_SIM_FTM0, SIM_SCGC6, 24			// BBA des Bits fuer den FTM0 im SIM
__BBREG	BB_FTM0_TOF, FTM0_SC, 7 			// BBA des Timer Overflow Flags des FTM0
__BBREG BB_FTM0_CHF, FTM0_C3SC, 7 			// BBA des Channel Overflow Flags des FTM0

.equ FTM0_IRQ_OFS, 0x138					// Offset fuer den FTM0 in der IVT
.equ FTM0_NVIC_MASK, 0x40000000				// IRQ mod 32 = 62 mod 32 = 30 -> vorletztes Bit im NVIC

// FTM Intialregisterwerte
.equ CONF_INIT, 	0xc						// Aktiviere BDM fuer den Debug Modus
.equ FMS_INIT,	    0x0						// Cleare WPM Bit, so dass WPDIS gesetzt wird, gemaess Hinweise fuer FTM Applikationen
.equ MODE_INIT, 	0x5						// Ermoegliche das Schreiben in FTM Register
.equ CNTIN_INIT,    0x0						// Der initiale Zaehlerwert wird auf 0 eingestellt
.equ MOD_INIT, 	    24999					// 25MHz System Clock -> 1000kHz entspricht 25000 Takte
.equ C3SC_INIT,	    0x68					// aktiviere Channel Interrupts, Initialier PWN Status ist high und Flankenausrichtung
.equ COMBINE_INIT,  0x2000					// Combine Modus deaktivieren, Software Trigger fuer CH2 und CH3 aktiviert
.equ DEADTIME_INIT, 0x0 					// Setze deadtime auf 0
.equ C3V_INIT, 	    21249					// Es wurde initial ein Wert fuer 15% der Grundschwingung voreingestellt (Berechnung siehe unten)
.equ SC_INIT, 	    0x48					// Aktiviere Overflow Interrupts, Aufwaertszaehler, Systemtakt
.equ SYNCONF_INIT,  0x1380					// Aktiviere SWWRBUF, SWRSTCNT und SYNCMODE, um die Synchronisation nach Software Triggern zu unterstuetzen
.equ SYNC_TRIG, 	0x80					// Konstante, die wenn in FTM0_SYNC geschrieben einen Software Trigger zur Synchronisation ausloest	
.equ POL_POS,      	0x0						// Konstante fuer positive Polaritaet
.equ POL_NEG,      	0x8						// Konstante fuer negative Polaritaet -> fuer CH3

// allgemeine Konstanten
.equ LF, 	0x0a
.equ PROMPT,'>'
.equ ZERO, 	0x30
.equ ONE, 	0x31
.equ TWO, 	0x32
.equ THREE, 0x33
.equ FOUR, 	0x34
.equ FIVE, 	0x35
.equ SIX, 	0x36
.equ SEVEN, 0x37
.equ EIGHT, 0x38
.equ NINE, 	0x39
.equ PLUS, 	0x2b
.equ MINUS, 0x2d
.equ NUM_MSK, 0xf

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init

// Register mit wichtigen Adressen und Werten vorbelegen
	mov r10, #1
	ldr r11, =pol_flag
	ldr r12, =pwm_flag

// Initialisierung von PORTA GPIO Modul fuer PTA6
	ldr r0, =SIM_PORTA				// Takt fuer die benutzten Module aktivieren
	str r10, [r0]
		
	ldr r0, =PORTA_PCR0 			// Startadresse der Port A PCR-Register
	ldr r1, =SET_FTM0 				// GPIO-Modus fuer LED festlegen
	str r1, [r0, #PCR6]				// Stelle diesen fuer PTA6 ein und
	
	ldr r0, =GPIOA_PDDR				// Ausgaeng (fuer PTA6 konfigurieren)
	ldr r1, =PDDR_MASK_FTM0
	ldr r2, [r0]
	orr	r2, r2, r1
	str r2, [r0]
	
// FTM Modul intialisieren und konfigurieren (Werte und Erklaerungen s.o.)
	ldr r0, =BB_SIM_FTM0
	str r10, [r0]

	ldr r0, =FTM0_CONF
	mov r1, #CONF_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_FMS
	mov r1, #FMS_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_MODE
	mov r1, #MODE_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_CNTIN
	mov r1, #CNTIN_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_MOD
	ldr r1, =MOD_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_C3SC
	mov r1, #C3SC_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_COMBINE
	ldr r1, =COMBINE_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_DEADTIME
	mov r1, #DEADTIME_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_C3V
	ldr r1, =C3V_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_SC
	mov r1, #SC_INIT
	str r1, [r0]
	
	ldr r0, =FTM0_SYNCONF
	mov r1, #SYNCONF_INIT
	str r1, [r0]
	
// Interupts und ISR eintragen
	ldr r0, =SCR_VTOR				// Basisadresse der IVT
	ldr r1, [r0]					// laden
	ldr r0, =isr_ftm				// ISR fuer den FTM (alle Quellen) 
	str r0, [r1, #FTM0_IRQ_OFS]		// in die IVT eintragen
	
	ldr r0, =NVIC_ICPR1				// Pending (haengende) im NVIC loeschen
	mov r1, #FTM0_NVIC_MASK			// Bit für RTC-IRQ in den NVIC-Registern
	str r1, [r0]
	ldr r0, =NVIC_ISER1				// IRQs zu RTC im NVIC aktivieren
	str r1, [r0]					// r1 hat noch den Wert (RTC_NVIC_MASK), also nicht neu laden	

main_loop:
	mov r0, #PROMPT
	bl uart_putChar

wait_for_input:
	bl	uart_charPresent			// wurde ein Zeichen eingegeben?
	cbnz r0, check_input			// ja, pruefen

	b wait_for_input				// nein, warte weiter
	
check_input:
	bl	uart_getChar				// eingegebenes Zeichen einlesen
	cmp	r0, #PLUS					// war es ein '+'?
	beq	c_pol						// ja, verzeigen
	cmp	r0, #MINUS					// war es ein '-'?
	beq	c_pol						// ja, verzeigen
	cmp	r0, #ZERO					// war es eine '0'?
	beq	c_pwm						// ja, verzeigen
	cmp	r0, #ONE					// war es eine '1'?
	beq	c_pwm						// ja, verzeigen
	cmp	r0, #TWO					// war es eine '2'?
	beq	c_pwm						// ja, verzeigen
	cmp	r0, #THREE					// war es eine '3'?
	beq	c_pwm						// ja, verzeigen
	cmp	r0, #FOUR					// war es eine '4'?
	beq	c_pwm						// ja, verzeigen
	cmp	r0, #FIVE					// war es eine '5'?
	beq	c_pwm						// ja, verzeigen
	cmp	r0, #SIX					// war es eine '6'?
	beq	c_pwm						// ja, verzeigen
	cmp	r0, #SEVEN					// war es eine '7'?
	beq	c_pwm						// ja, verzeigen
	cmp	r0, #EIGHT					// war es eine '8'?
	beq	c_pwm						// ja, verzeigen
	cmp	r0, #NINE					// war es eine '9'?
	beq	c_pwm						// ja, verzeigen
	
	mov r0, #LF						// Gib bei ungueltiger Eingabe ein Zeilenumbruch aus
	bl uart_putChar
	
	b	main_loop					// keine gueltige Eingabe, normal weitermachen
	
c_pol:
	cmp r0, 0x2b					// Pruefe ob ein '+' eingegeben wurde und
	ite eq							
	moveq r1, #1					// schreibe einen entsprechenden Wert in die pol_flag 
	movne r1, #2					// Variable (1 = '+' und 2 = '-')
	str r1, [r11]
	bl	uart_putChar				// Gebe eingegebenes Zeichen zur Kontrolle aus
	mov	r0, #LF						// neue Zeile
	bl	uart_putChar				// ausgeben

	b 	main_loop					// zurueck zum Anfang
	
c_pwm:
	mov r1, #NUM_MSK				// Lade Maske, um HEX Wert der Eingabe 
	and r0, r0, r1					// durch verunden zu erhalten
	str r0, [r12]	
	bl	uart_putByteBase10			// zur Kontrolle ausgeben
	mov	r0, #LF						// neue Zeile
	bl	uart_putChar				// ausgeben
	
	b 	main_loop					// zurueck zum Anfang

/*
 * FTM-ISR - Hier wird zuerst geprueft, um welche Art von Interrupt es sich handelt.
 * Dann wird geprueft, ob eine Eingabe auf dem Terminal stattgefunden hat. Ist dies
 * der Fall so wird entsprechend gehandelt. Die Uebergabe von Daten geschieht hierbei 
 * ueber den Speicher und die PWM wird bei einem Channel Interrupt bearbeitet und die
 * Polaritaet entsprechend bei einem Overflow Interrupt.
 *
 * Parameter: keine	
 * Rueckgabe: keine
 */	
.thumb_func
isr_ftm:
	ldr r0, =BB_FTM0_CHF			// Lade BBA des Channel Interrupt Flags
	ldr r1, [r0]					// Lese Inhalt des Flags
	cmp r1, #0						// Wenn Flag nicht gesetzt
	beq overflow					// Springe zur Behandlung des Overflows (es kann nur Channel oder Overflow Interrupts geben)
	
	mov r1, #0						// Wenn ein Channel Interrupt vorliegt, 
	str r1, [r0]					// schreibe eine 0 an die BBA (cleare Channel Interrupt Flag)

	ldr r0, =pwm_flag				// Lade das pwm Flag 
	ldr r1, [r0]					// und pruefe, ob dieses gesetzt wurde
	cmp r1, 0xa						// Wurde es nicht gesetzt, 
	beq end_isr						// springe zum Ende der ISR
	
	mov r2, 0xa						// Setze pwm_flag zurueck
	str r2, [r0]					// der Wert 0xa steht fuer "nicht gedrueckt"
	
	ldr r2, =table_pwm_time			// Lade die Adresse der Tabelle mit den Zeitwerten aus dem Speicher
	ldr r3, [r2, r1, lsl #2]		// Waehle Eintrag aus der Tabelle, der Eingabe
	ldr r2, [r3]					// entsprechend
	
	ldr r1, =FTM0_C3V				// Lade die Adresse des Registers fuer den neuen Zeitwert
	str r2, [r1]					// und lege ausgewaehlten Wert dort ab
	
	ldr r1, =FTM0_SYNC				// Schreibe eine 1 an FTM0_SYNC um eine
	mov r2, #SYNC_TRIG				// Synchronisation auszuloesen
	str r2, [r1]
	
	b end_isr						// Springe zum Ende
	
overflow:
	ldr r0, =BB_FTM0_TOF			// Lade BBA des Overflow Interrupt Flags
	ldr r1, [r0]					// Lese Inhalt (es muss nicht verglichen werden, da kein anderer Interrupt auftreten kann)
	
	mov r1, #0						// Nach dem Lesen, kann dann eine 0 geschrieben werden,
	str r1, [r0]					// um das Overflow Interrupt Flag zu clearen

	ldr r0, =pol_flag				// Lade Adresse und 
	ldr r1, [r0]					// Wert des pol Flags
	cmp r1, 0x0						// wurde es nicht gesetzt
	beq end_isr						// springe zum Ende
	
	mov r2, 0x0
	str r2, [r0]					// Setze pol_flag zurueck
	
	cmp r1, #0x1					// Wurde das pol Flag gesetzt, dann lade r0 mit
	ite eq
	moveq r0, #POL_POS              // einer Konstante fuer Polarity high oder
	movne r0, #POL_NEG				// einer Konstante fuer Polarity low
	ldr r1, =FTM0_POL				// Lade Adresse des Polaritaetsregisters
	str r0, [r1]					// Aendere Polaritaet gemaess der Eingabe
	
	ldr r1, =FTM0_SYNC				// Schreibe eine 1 an FTM0_SYNC um eine
	mov r2, #SYNC_TRIG				// Synchronisation auszuloesen
	str r2, [r1]
	
end_isr:
	bx lr							// Springe zurueck aus ISR
	
/*** Datenbereich (ab 0x20000000) ***/
.data
pol_flag: .word 0					// 0 = es wurde nichts eingegeben, 1 = es wurde ein '+' eingegeben und 2 = es wurde ein '-' eingegeben
pwm_flag: .word 10					// enthaelt den Wert der ggf. eingegeben wurde, der Wert 10 bedeutet keine aktuelle Eingabe

// Tabelle der Adressen der Zeiten fuer die verschiedenen PWM Signale
table_pwm_time: .word pwm_time_5, pwm_time_15, pwm_time_25, pwm_time_35, pwm_time_45, pwm_time_55, pwm_time_65, pwm_time_75, pwm_time_85, pwm_time_95

// Liste der Zeiten (Berechnung mit der Formel (Grundschwingung - (Grundschwingung*n)/100), wobei n die jeweilige Stufe ist und die Grundschwingung ist 1kHz)
pwm_time_5: .word  23749		// Entspricht 5% der Grundschwingung
pwm_time_15: .word 21249		// Entspricht 15% der Grundschwingung
pwm_time_25: .word 18749		// Entspricht 25% der Grundschwingung
pwm_time_35: .word 16249		// Entspricht 35% der Grundschwingung
pwm_time_45: .word 13749		// Entspricht 45% der Grundschwingung
pwm_time_55: .word 11249		// Entspricht 55% der Grundschwingung
pwm_time_65: .word 8749			// Entspricht 65% der Grundschwingung
pwm_time_75: .word 6249			// Entspricht 75% der Grundschwingung
pwm_time_85: .word 3749			// Entspricht 85% der Grundschwingung
pwm_time_95: .word 1249			// Entspricht 95% der Grundschwingung
