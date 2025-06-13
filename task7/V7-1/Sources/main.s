/************************************************************
Versuch: 7-1
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 13 Stunden
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
.equ SIM_SCGC6,	 	0x4004803C

// Allgemeine Adressen fuer die Interrupt Konfiguration
.equ SCR_VTOR,		0xE000ED08			// Register für die Interrupt-Vektor-Tabelle (IVT)

.equ NVIC_ISER2, 	0xE000E108
.equ NVIC_ICPR2, 	0xE000E288

// Konstanten fuer die Initialisierung und Konfiguration vom RTC Modul

.equ RTC_TSR, 0x4003D000 				// RTC Time Seconds Register 
.equ RTC_TAR, 0x4003D008  				// Time Alarm Register 
.equ RTC_CR,  0x4003D010  				// Control Register
.equ RTC_SR,  0x4003D014 				// Status Register 
.equ RTC_LR,  0x4003D018 				// Lock Register
.equ RTC_IER, 0x4003D01C 				// Interrupt Enable Register
.equ RTC_WAR, 0x4003D800 				// Write Access Register 
.equ RTC_RAR, 0x4003D804 				// Read Access Register 

.equ RTC_CR_INIT, 0x100					// Aktiviere OSCE im Kontrollregister, Rest auf 0
.equ RTC_OSC_STARTUP, 25000000			// Oszillator Startup Zeit (s. K60 Sub-Family Data Sheet, S.33 -> 1000ms = 1 s Wartezeit. Entspricht 25000000 Takten)
.equ RTC_TAR_24_VAL, 86399				// 23:59:59 (hh:mm:ss) entspricht 86399 Sekunden
.equ RTC_TSR_24_VAL_PRE, 86395			// 23:59:55 (hh:mm:ss) entspricht 86395 Sekunden
.equ RTC_TAR_1_VAL, 3599				// 59:59 (mm:ss) entspricht 3599 Sekunden
.equ RTC_TSR_1_VAL_PRE, 3595			// 59:55 (mm:ss) entspricht 3595 Sekunden
.equ RTC_TSR_RESET, 0x0					// Um das TSR Register zurueckzusetzen (im Programmverlauf und am Anfang)
.equ RTC_RAR_INIT, 0xff					// Erlaube alle Reads
.equ RTC_WAR_INIT, 0xf5					// Erlaube Writes ausser Prescale und Compensation Writes
.equ RTC_LR_INIT, 0x78					// Stelle alles auf nicht locked
.equ RTC_IER_INIT, 0x14					// Enable TSI (Seconds Interrupt) und TAI (Alarm Interrupt)

__BBREG RTC_SR_TCE, RTC_SR, 4			// BBA des TCE Bits mit dem der Zaehler deaktiviert und aktiviert werden kann

.equ RTC_IRQ_ALA_OFS, 0x148				// Interrupt Request Offset fuer RTC Alarminterrupts
.equ RTC_IRQ_SEC_OFS, 0x14C				// Interrupt Request Offset fuer RTC Sekundeninterrupts

.equ RTC_NVIC_MASK, 0xc					// Bitposition für die Interrupts (Alarm und Seconds) in NVIC-Registern (1 << (66 % 32) und 1 << (67 % 32))

__BBREG SIM_RTC, SIM_SCGC6, 29			// Bit-Band-Alias-Adresse fuer die RTC im SIM-Register

// Allgemeine Konstanten
.equ LF, 0x0A							// Line Feed (neue Zeile)
.equ SP, 0x20							// Space
.equ COLON, 0x3A
.equ CHAR_D, 'd'
.equ CHAR_H, 'h'
.equ CHAR_R, 'r'
.equ CHAR_S, 's'
.equ CHAR_P, 'p'
.equ HOURS_DIV, 3600					// Konstanten fuer die Umrechnung der Stunden
.equ MINUTES_DIV, 60					// und Minuten

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init

// Register mit wichtigen Adressen vorbelegen
	mov r6, #0
	mov r7, #1
	ldr r8, =RTC_TSR				// Lade Adresse des Sekundenzaehlers des RTC Moduls
	ldr r9, =end					// Lade Adresse der end Variable - Zeigt an, ob der Endzeitpunkt erreicht wurde (wird in Alarm ISR gesetzt)
	ldr r10, =display				// Lade Adresse der display Variable - Zeigt an, ob die Anzeige gerade an ist 
	ldr r11, =mode					// Lade Adresse der mode Variable (zeigt programmuebergreifend an in welchem Modus sich das Programm befindet)
	ldr r12, =user_flag				// Lade Adresse des user flags fuer die 1 Sekunde Verzoegerung

// Initialisierung und Konfiguration des RTC Modules - TPR und PCR werden nicht initialisiert, da im WAR eingestellt ist, dass sie ignoriert werden.
	ldr r0, =SIM_RTC				// SIM Aktivierung
	str r7, [r0]
			
	ldr r0, =RTC_CR					// Konfiguriere RTC Kontrollregister
	mov r1, #RTC_CR_INIT
	str r1, [r0]
	
	ldr r0, =RTC_OSC_STARTUP		// Lade Wert fuer Oszillator Startup Zeit (s. K60 Sub-Family Data Sheet, S.33)

osc_start:							// Loop fuer die Oszillator Startup Zeit
	subs r0, r0, #1
	bne osc_start
			
	ldr r0, =RTC_RAR				// Konfigurieren des Read Access Registers. Es werden hier
	mov r1, #RTC_RAR_INIT			// alle Reads erlaubt.	
	str r1, [r0]

	ldr r0, =RTC_WAR				// Konfigurieren des Write Access Registers. Es werden alle writes
	mov r1, #RTC_WAR_INIT			// erlaubt ausser Prescaler und Compensation Writes (deshalb werden die Register TPR, PCR ignoriert)
	str r1, [r0] 
	
	ldr r0, =RTC_LR					// Konfigurieren des Lock Registers
	mov r1, #RTC_LR_INIT			// Es wird alles nicht locked eingestellt
	str r1, [r0]
	
	ldr r0, =RTC_IER				// Konfiguririe Interrupt Enable Register 
	mov r1, #RTC_IER_INIT			// Es werden Sekunden und Alarminterrupts eingeschaltet (vgl. Wert der Variable, s.o.)
	str r1, [r0]
		
// Interupts und ISR eintragen
	ldr r0, =SCR_VTOR				// Basisadresse der IVT
	ldr r1, [r0]					// laden
	ldr r0, =isr_rtc_tai			// ISR fuer den RTC (Alarm Interrupt) 
	str r0, [r1, #RTC_IRQ_ALA_OFS]	// in die IVT eintragen
	ldr r0, =isr_rtc_tsi			// ISR fuer den RTC (Seconds Interrupt) 
	str r0, [r1, #RTC_IRQ_SEC_OFS]	// in die IVT eintragen
	
	ldr r0, =NVIC_ICPR2				// Pending (haengende) im NVIC loeschen
	mov r1, #RTC_NVIC_MASK			// Bit für RTC-IRQ in den NVIC-Registern
	str r1, [r0]
	ldr r0, =NVIC_ISER2				// IRQs zu RTC im NVIC aktivieren
	str r1, [r0]					// R1 hat noch den Wert (RTC_NVIC_MASK), also nicht neu laden	

// Werte fuer TSR und TAR eintragen und Zaehler starten (passiert im UP)	
	ldr r0, =RTC_TAR_24_VAL			// Uebergebe Wert fuer 24 Stunden
	ldr r1, [r11]					// Uebergebe Initialwert der mode Variable an UP
	
	bl change_mode

// Beginn Hauptloop des Programmes
main_loop:
	bl	uart_charPresent			// wurde ein Zeichen eingegeben?
	cbnz r0, check_input			// ja, pruefen
	ldr r0, [r10]					// Variable fuer Display an/aus laden
	cmp	r0, #1						// laeuft die Anzeige?
	bne	main_loop					// nein, nur die Eingabe abfragen
	
	strb r6, [r12]					// Benutzerflag zuruecksetzen (= 0)

	ldr r0, [r9]					// Lade Wert der end Variable und vergleiche,
	cmp r0, #1						// ob der Endzeitpunkt erreicht wurde
	beq end_reached					// Wurde dieser erreicht, springe zu entsprechendem Programmteil
	 
	ldr r0, [r8]					// Lade Wert des TSR Registers (Sekundenzaehlregister, Uebergabe an UP)

	ldr r1, [r11]					// Lade Wert der mode Variable (Uebergabe an UP)
	
	bl print_curr_time 

poll_loop:
	ldrb r0, [r12]					// Flag laden
	cmp	r0, #1						// Benutzerflag = Eins? 
	bne	poll_loop					// Nein -> weiter warten
		
	b 	main_loop					// das Ganze von vorn

end_reached:					
	str r6, [r9]					// End Flag zuruecksetzen (= 0)
	
	ldr r0, =RTC_SR_TCE				// BBA des TCE Bits im SR Register, um Zaehler zu de-/aktivieren	
	str r6, [r0]					// Schalte den Zaehler aus
	str r6, [r8]					// Setze den Wert des Zaehlregisters auf 0
	str r7, [r0]					// Schalte den Zaehler ein
	
	ldr r0, =str_reached_end		// Gebe String aus fuer den Endzeitpunkt
	bl uart_putString
	
	b main_loop						// Zurueck zum main_loop

check_input:
	bl	uart_getChar				// eingegebenes Zeichen einlesen
	cmp	r0, #CHAR_D					// war es ein 'd'?
	beq	input_d						// ja, verzeigen
	cmp	r0, #CHAR_H					// war es ein 'h'?
	beq	input_h						// ja, verzeigen
	cmp	r0, #CHAR_R					// war es ein 'r'?
	beq	input_r						// ja, verzeigen
	cmp	r0, #CHAR_S					// war es ein 's'?
	beq	input_s						// ja, verzeigen
	cmp	r0, #CHAR_P					// war es ein 'p'?
	beq	input_p						// ja, verzeigen	
	b	main_loop					// keine gueltige Eingabe, normal weitermachen

input_d:
	str r7, [r11]					// Setze mode Variable auf 1 (fuer den 24 Stunden Modus -> hh:mm:ss)
	
	ldr r0, =RTC_TAR_24_VAL			// Uebergebe Wert fuer 24 Stunden Modus
	mov r1, r7						// Uebergebe Wert der mode Variable an UP (2 Zeilen darueber wurde r7(1) in r11 gespeichert)
	bl change_mode					// UP, um Modus zu aendern
	b main_loop						// Zurueck zu main_loop
	
input_h:
	str r6, [r11]					// Setze mode Variable auf 0 (fuer den 1 Stunden Modus -> mm:ss)

	ldr r0, =RTC_TAR_1_VAL			// Uebergebe Wert fuer 1 Stunden Modus
	mov r1, r6						// Uebergebe Wert der mode Variable an UP (2 Zeilen darueber wurde r6(0) in r11 gespeichert)
	bl change_mode					// UP, um Modus zu aendern
	b main_loop						// Zurueck zu main_loop
	
input_r:
	bl reset_tsr					// Rufe UP auf zum Zuruecksetzen des Zaehlregisters
	b main_loop
	
input_s:
	ldrb r1, [r10]					// Variable fuer Start/Stopp laden
	cmp r1, #1						// mit eins (= Display an) vergleichen
	ite ne							// Bedingung vorgeben
	ldrne r0, =str_display_on		// entsprechenden String auswaehlen
	ldreq r0, =str_display_off
	eor r1, r1, #1					// Variable umkehren
	str r1, [r10]					// und zurueckschreiben
	bl	uart_putString				// gewaehlten String ausgeben
	b 	main_loop					// zurueck zum Anfang
	
input_p:
	ldr r0, [r11]					// Lade Wert der mode Variable
	cmp r0, #0						// Ist diese ungleich 0, so lade
	ite ne
	ldrne r1, =RTC_TSR_24_VAL_PRE	// den Wert fuer den 24 Stunden Modus
	ldreq r1, =RTC_TSR_1_VAL_PRE	// und sonst den Wert fuer den 1 Stunden Modus
	
	ldr r0, =RTC_SR_TCE				// BBA des TCE Bits im SR Register, um Zaehler zu de-/aktivieren	
	str r6, [r0]					// Schalte den Zaehler aus
	str r1, [r8]					// Setze den Wert des Zaehlregisters (TSR) auf den oben ausgewaehlten preset Wert
	str r7, [r0]					// Schalte den Zaehler ein
	
	ldr r0, =str_skip_time			// Lade und drucke String, um anzuzeigen, dass
	bl uart_putString				// in der Zeit gesprungen wurde

	b main_loop						// Zurueck zu main_loop
	
/* Unterprogramme und ISRs */	

/*
 * Druckt die aktuelle Zeit auf das Terminal und beruecksichtigt dabei den aktuellen Modus.
 *
 * Parameter: In r0 wird die aktuelle Zeit uebergeben. 
 *	 	 	  In r1 der aktuelle Wert der mode Variable (die Ausgabe kann so angepasst werden).
 * Rueckgabe: keine
 */		
.thumb_func
print_curr_time:
	push {r4,r5,r6,r7,lr}			// Sichere verwendetete Register und lr
	
	cmp r1, #1						// Verleiche den uebergebenen Wert der mode Variable mit 1
	it ne							// Ist das Programm im Stundenmodus, so wird die uebergebene
	movne r5, r0					// Zeit an r5 durchgereicht und es wird
	bne skip_hours					// weitergesprungen, um das Berechnen und Drucken der Stunden zu ueberspringen
	
	// Stunden berechnen
    mov r1, #HOURS_DIV       		// Lade 3600 in r1 (Anzahl der Sekunden pro Stunde)
    udiv r4, r0, r1     			// r4 = r0 / r1 (Stunden in r4)
    mls  r5, r4, r1, r0 			// r5 = r0 - (r1 * r4) (Reste für Minuten)

    // Stunden ausgeben
    mov r0, r4
    bl out_leading0    
    mov r0, #COLON
    bl uart_putChar

skip_hours:
    // Minuten berechnen
    mov r1, #MINUTES_DIV         	// Lade 60 in r1 (Anzahl der Sekunden pro Minute)
    udiv r6, r5, r1     			// r6 = r5 / r1 (Minuten in R4)
    mls  r7, r6, r1, r5 			// r7 = r5 - (r1 * r6) (Reste für Sekunden)
    
    // Minuten ausgeben
    mov r0, r6
    bl out_leading0   
    mov r0, #COLON
    bl uart_putChar
    
    // Sekunden ausgeben (der Rest in r7)
    mov r0, r7
    bl out_leading0   
    mov r0, #LF
    bl uart_putChar 
	
	pop {r4,r5,r6,r7,pc}			// Stelle Register wieder her und springe zurueck

/*
 * Aendert eine den Inhalt des TAR Registers (Wechsel zwischen 24 und 1 Stunden Modus)
 *
 * Parameter: In r0 wird eine Zahl uebergeben, die in das Alarmregister geschrieben werden soll.
 *	 	 	  In r1 wird der Wert der mode Variable uebergeben.
 * Rueckgabe: keine
 */		
.thumb_func
change_mode:
	push {lr}						// Sichere lr
	ldr r2, =RTC_TAR				
	str r0, [r2]					// Speichere uebergebenen Wert in das Alarm Register
	cmp r1, #0						// Vergleiche uebergebenen Wert der mode Variable mit 0 (= 1 Stunden Modus)
	ite ne							// Bedingung vorgeben
	ldrne r0, =str_mode_24			// entsprechenden String auswaehlen
	ldreq r0, =str_mode_1
	bl uart_putString				// String ausgeben
	bl reset_tsr					// UP, um Sekundenzaehlregister zuruecksetzen
	pop {pc}						// Springe zurueck ins Hauptprogramm

/*
 * Setzt den Wert im Sekundenzaehlregister(TSR) auf 0 zurueck.
 *
 * Parameter: keine
 * Rueckgabe: keine
 */		
.thumb_func
reset_tsr:
	push {lr}						// Sichere lr	
	mov r0, #0						// Lade genutzte Werte vor
	mov r1, #1
	ldr r2, =RTC_SR_TCE				// BBA des TCE Bits im SR Register, um Zaehler zu de-/aktivieren
	ldr r3, =RTC_TSR				// Lade Adresse des Sekundenzaehlregisters (TSR)	
	str r0, [r2]					// Schalte den Zaehler aus
	str r0, [r3]					// Setze den Wert des Zaehlregisters auf 0
	str r1, [r2]					// Schalte den Zaehler ein
	ldr r0, =str_reset				// Gebe Reset String aus
	bl uart_putString	
	pop {pc}						// Springe zurueck
	
/*
 * Gibt bei Zahlen < 10 eine fuehrende Null aus.
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
 * RTC-ISR fuer TSI (Interrupt Service Routine fuer Time Seconds Interrupt)
 *
 * Parameter: keine Parameter moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 * Rueckgabe: keine Rueckgabe moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 */		
.thumb_func
isr_rtc_tsi:
	mov r1, #0x1
	ldr r0, =user_flag				// Benutzerflag setzen
	str r1, [r0]
	bx lr
	
/*
 * RTC-ISR fuer TAI (Interrupt Service Routine fuer Time Alarm Interrupt)
 *
 * Parameter: keine Parameter moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 * Rueckgabe: keine Rueckgabe moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 */		
.thumb_func
isr_rtc_tai:
	ldr r0, =RTC_TAR
	ldr r1, [r0]
	str r1, [r0]
	
	ldr r0, =end						// Lade genutzte Werte vor
	mov r1, #1
	str r1, [r0]
	
	bx lr
	
/*** Datenbereich (ab 0x20000000) ***/
.data
user_flag: .word 0									// Flag, das im Sekundeninterrupt gesetzt wird
mode: .word 1										// Modus Variable, um Modus im Programmverlauf anzeigen zu koennen. (0 = 1 Stunde, 1 = 24 Stunden)
display: .word 1									// Eine Variable, um anzuzeigen, ob die Zeit aktuell angezeigt werden soll oder nicht (0 = Stop, 1 = Anzeige)
end: .word 0										// Eine Variable, die anzeigt, ob der Endzeitpunkt erreicht wurde (wird in der Alarm ISR gesetzt)

str_mode_24: .asciz "24-Stunden-Modus\n"
str_mode_1: .asciz "1-Stunden-Modus\n"
str_reset: .asciz "Uhr zurueckgesetzt\n"
str_display_on: .asciz "Anzeige an\n"
str_display_off: .asciz "Anzeige aus\n"
str_skip_time: .asciz "Uhr vorgestellt\n"
str_reached_end: .asciz "Endzeitpunkt erreicht\n"
