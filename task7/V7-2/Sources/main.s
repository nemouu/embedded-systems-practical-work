/************************************************************
Versuch: 7-2
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 20 Stunden
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

.equ NVIC_ISER2, 	0xE000E108
.equ NVIC_ICPR2, 	0xE000E288

// Konstanten fuer die Intialisierung und Konfiguration vom PIT Modul
.equ PIT_MCR,       0x40037000
.equ PIT_LDVAL1,    0x40037110
.equ PIT_TCTRL1,    0x40037118
.equ PIT_TFLG1,     0x4003711C
.equ PIT1_IRQ_OFS,	0x154					// Interrupt Request Offset für PIT1
.equ PIT1_NVIC_MASK, 1 << (69 % 32)			// Bitposition für PIT-IRQ in NVIC-Registern (IRQ mod 32)

.equ PIT_COUNT_100, 2500000-1				// 2500000	Takte bei 25 MHz => 0.1 Sekunden => 100 ms
.equ PIT_COUNT_200, 5000000-1				// 5000000	Takte bei 25 MHz => 0.2 Sekunden => 200 ms
.equ PIT_MCR_VAL, 0							// MDIS = 0, FRZ = 0
.equ PIT_TCTRL1_VAL, 2						// CHN = 0, TIE = 1, TEN = 0 (Timer wird erst im Programmverlauf angeschaltet)

__BBREG BB_SIM_PIT, SIM_SCGC6, 23			// Bit-Band-Alias-Adresse fuer den PIT im SIM-Register
__BBREG PIT_TCTRL1_TEN, PIT_TCTRL1, 0		// Bit-Band-Alias-Adresse fuer das Enable Bit des PIT, so kann dieser schneller ein- und ausgeschaltet werden

// Konstanten fuer die Initialisierung und Konfiguration von PORTA GPIO Modul (LED E4 und PTA6)
.equ GPIOA_PDOR,    0x400FF000
.equ GPIOA_PDDR,    0x400FF014
.equ PORTA_PCR0,	  0x40049000		    // Adresse der Port A PCR-Registers
.equ PDDR_MASK_LEDE4_PTA6, (1<<6 | 1<<10 )	// Maske fuer den Ausgang PTA6 und die LED E4
.equ GPIO_SET_LED, 0x120					// GPIO-Modus, Open-Drain
.equ GPIO_SET_PTA6, 0x100					// GPIO-Modus

// Bit Band-Konstanten
__BBREG	SIM_PORTA, SIM_SCGC5, 9
__BBREG	E4, GPIOA_PDOR, 10
__BBREG	PTA6, GPIOA_PDOR, 6

// Offsets für die einzelnen PCR-Register
.equ PCR6,	0x18				// PTA6
.equ PCR10,	0x28				// E4

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
.equ RTC_TAR_24_VAL, 59					// So wird alle 60 Sekunden (im Minutentakt) ein Alarminterupt ausgeloest und damit ein Flag gesetzt.
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
.equ SPACE, ' '
.equ DOT, '.'
.equ CHAR_T, 't'
.equ CHAR_D, 'd'
.equ CHAR_H, 'h'
.equ CHAR_R, 'r'
.equ CHAR_S, 's'
.equ CHAR_P, 'p'
.equ TAR_24_MAX_VAL, 86400
.equ HOURS_DIV, 3600					// Konstanten fuer die Umrechnung der Stunden
.equ MINUTES_DIV, 60					// und Minuten
.equ MAX_MI, 60							// Maxima für Zeit und Datum
.equ MAX_H, 24
.equ MAX_D, 30
.equ MAX_MO, 12
.equ MAX_Y, 100
.equ WEDNESDAY, 0x6
.equ DCF77_START, 0x140000				// Start der Kodierung ist eine 1 und es ist CET eingestellt

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init
	
	bl pit1_init

// Register mit wichtigen Adressen vorbelegen
	mov r8, #0
	mov r9, #1
	ldr r10, =RTC_TSR				// Lade Adresse des Sekundenzaehlers des RTC Moduls
	ldr r11, =start_tra				// Lade Adresse der end Variable - Zeigt an, ob der Endzeitpunkt erreicht wurde (wird in Alarm ISR gesetzt)
	ldr r12, =date_time				// Lade Adresse der datetime Variable, um diese zur Laufzeit aendern zu koennen

// Initialisierung von PORTA GPIO Modul fuer LED E4 und PTA6
	ldr r0, =SIM_PORTA				// Takt fuer die benutzten Module aktivieren
	str r9, [r0]
		
	ldr r0, =PORTA_PCR0 			// Startadresse der Port A PCR-Register
	mov r1, #GPIO_SET_LED 			// GPIO-Modus fuer LED festlegen
	str r1, [r0, #PCR10]			// Stelle diesen fuer PTA6 ein und
	mov r1, #GPIO_SET_PTA6			// GPIO-Modus fuer PTA6 festlegen
 	str r1, [r0, #PCR6]				// Stelle diesen dann fuer E4 ein
	
	ldr r0, =GPIOA_PDDR				// Ausgaeng (fuer LED E4 und PTA6)
	ldr r1, =PDDR_MASK_LEDE4_PTA6
	ldr r2, [r0]
	orr	r2, r2, r1
	str r2, [r0]
	
	ldr r0, =E4						// Setze E4 und PTA6 zu Beginn auf LOW
	ldr r1, =PTA6
	str r9, [r0]
	str r9, [r1]
	
// Initialisierung und Konfiguration des RTC Modules - TPR und PCR werden nicht initialisiert, da im WAR eingestellt ist, dass sie ignoriert werden.
	ldr r0, =SIM_RTC				// SIM Aktivierung
	str r9, [r0]
			
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

// Werte fuer TSR und TAR eintragen und Zaehler starten 	
	ldr r0, =RTC_TAR_24_VAL			// Uebergebe Wert fuer 60 Sekunden
	ldr r1, =RTC_TAR				// Uebergebe Initialwert der mode Variable an UP
	str r0, [r1]

// Intiale Abfrage fuer ein Datum (es wird davon ausgegangen, dass ein gueltiges Datum eingegeben wird)	
	ldr r0, =str_std				// Text zur Stundenabfrage waehlen,
	bl	echo_input					// ausgeben und Eingabe abholen
	strb r0, [r12, #3]				// abspeichern
	ldr r0, =str_min				// gleicher Vorgang fuer die Minuten
	bl	echo_input
	strb r0, [r12, #4]

	ldr r0, =str_tag				// Text zur Tagesabfrage waehlen,
	bl	echo_input					// ausgeben und Eingabe abholen
	strb r0, [r12]					// abspeichern
	ldr r0, =str_mon				// gleicher Vorgang fuer den Monat 
	bl	echo_input
	strb r0, [r12, #1]
	ldr r0, =str_jhr				// gleicher Vorgang fuer das Jahr
	bl	echo_input
	strb r0, [r12, #2]
		
	str r9, [r11]					// Setze Flag fuer die Uebertragung, so wird direkt eine Uebertragung mit den neuen Werten gestartet
	bl reset_tsr					// UP, um Sekundenzaehlregister zuruecksetzen	

// Beginn Hauptloop des Programmes
main_loop:
	bl	uart_charPresent			// wurde ein Zeichen eingegeben?
	cbnz r0, check_input			// ja, pruefen
	
	ldr r1, =user_flag
poll_loop:
	ldrb r0, [r1]					// Flag laden
	cmp	r0, #1						// Benutzerflag = Eins? 
	bne	poll_loop					// Nein -> weiter warten	
	strb r8, [r1]					// Benutzerflag zuruecksetzen (= 0)
	
	ldr r0, [r11]					// Lade Wert der start transmit Variable und vergleiche,
	cmp r0, #1						// ob der 60 Sekunden vergangen sind.
	beq start_trans					// Wurde dieser erreicht, springe zu entsprechendem Programmteil
	
	bl put_curr_time				// Datum und Zeit ausgeben
	
	cmp r7, #21						// wenn Bit-Zähler < 21,
	itt lt
	andlt r0, r4, r9				// dann r0 = letztes Bit von r4 (Bits0-20)
	lsrlt r4, r4, #1				// Schiebe r4 nach rechts (das schon behandelte Bit wird rausgeschoben)
	blt output_dcf77				// Sprung zu output_dcf77
	
	cmp r7, #36						// wenn Bit-Zähler < 36,
	itt lt
	andlt r0, r5, r9				// dann r0 = letztes Bit von r5 (Zeit)
	lsrlt r5, r5, #1				// Schiebe r5 nach rechts (das schon behandelte Bit wird rausgeschoben)
	blt output_dcf77				// Sprung zu output_dcf77

    and r0, r6, r9					// sonst (muss ja 36-59 sein...Datum),
    lsr r6, r6, #1					// dann r0 = letztes Bit von r6, r6 >> 1, gehe zu output_dcf77

output_dcf77:						// Uebertragung des aktuellen Bits
	cmp r0, #0           			// Vergleicht r0 (aktuelles Bit) mit 0
	ite  ne                			// Bedingt den naechsten Befehl, wenn Gleichheit
	ldrne r1, =PIT_COUNT_200  		// Laedt PIT_COUNT_200 in r1, wenn r0 != 0
	ldreq r1, =PIT_COUNT_100		// Laedt PIT_COUNT_100 in r1, wenn r0 == 0
		
	ldr r0, =PIT_LDVAL1				// Speichere den entsprechenden Wert im PIT Wert Register ab
	str r1, [r0]
	
	ldr r0, =PIT_TCTRL1_TEN			// Schalte den PIT ein
	str r9, [r0]
	
	bl toggle_output_low			// Setze die Output Pins fuer LED E4 und PTA6 auf low (Signal Anfang, siehe Beschreibung des DCF77 Signals)
	
	ldr r0, =pit_flag
poll_loop_pit:
	ldrb r1, [r0]					// Flag laden
	cmp	r1, #1						// Benutzerflag = Eins? 
	bne	poll_loop_pit				// Nein -> weiter warten	
	strb r8, [r0]					// Benutzerflag zuruecksetzen (= 0)
	
	ldr r0, =PIT_TCTRL1_TEN			// Schalte den PIT wieder aus
	str r8, [r0]
	
	bl toggle_output_high			// Setze die Output Pins fuer LED E4 und PTA6 auf high (Signal Ende, siehe Beschreibung des DCF77 Signals)
	
    add r7, r7, #1					// Inkrementiere Zaehler

	bl inc_datetime					// Inkrementiere das aktuelle Datum

	b main_loop						// zurueck zum Hauptloop

check_input:
	bl	uart_getChar				// eingegebenes Zeichen einlesen
	cmp	r0, #CHAR_T					// war es ein 't'?
	beq	input_t						// ja, verzeigen
	cmp	r0, #CHAR_D					// war es ein 'd'?
	beq	input_d						// ja, verzeigen
	
	b	main_loop					// keine gueltige Eingabe, normal weitermachen

start_trans:
	str r8, [r11]					// Trans Flag zuruecksetzen (= 0)
	
	ldr r0, [r10]					// Lade Wert des TSR Registers (Sekundenzaehlregister, Uebergabe an UP)
	
	bl	put_datetime				// Wochentag, Datum und Zeit ausgeben
	
	bl curr_datetime
    
    ldr r4, =DCF77_START			// r4 = die ersten 20 bit (in Konstante gespeichert)
    mov r5, r0						// r5 = Minuten und Stunden (im letzten UP berechnet)
    mov r6, r1						// r6 = Datum (auch im letzten UP berechnet)   
	mov r7, #0						// Setze den Zaehler auf 0 (zurueck)

	ldr r0, =RTC_SR_TCE				// BBA des TCE Bits im SR Register, um Zaehler zu de-/aktivieren	
	str r8, [r0]					// Schalte den Zaehler aus
	str r8, [r10]					// Setze den Wert des Zaehlregisters auf 0
	str r9, [r0]					// Schalte den Zaehler ein
	
	ldr r0, =user_flag
	str r9, [r0]
	
	b main_loop
								
input_t:
	ldr r0, =str_std				// Text zur Stundenabfrage waehlen,
	bl	echo_input					// ausgeben und Eingabe abholen
	strb r0, [r12, #3]				// abspeichern
	ldr r0, =str_min				// gleicher Vorgang fuer die Minuten
	bl	echo_input
	strb r0, [r12, #4]
	
	mov r0, #0
	strb r0, [r12, #5]				// Sekunden auf 0 setzen (Ausrichtung der Uebertragung an vollen Minuten)
	bl reset_tsr
	bl put_curr_time				// Datum und Zeit ausgeben
	str r9, [r11]					// Setze Flag fuer die Uebertragung, so wird direkt eine Uebertragung mit den neuen Werten gestartet
	
	b 	main_loop					// zurueck zum Anfang
	
input_d:
	ldr r0, =str_tag				// Text zur Tagesabfrage waehlen,
	bl	echo_input					// ausgeben und Eingabe abholen
	strb r0, [r12]					// abspeichern
	ldr r0, =str_mon				// gleicher Vorgang fuer den Monat 
	bl	echo_input
	strb r0, [r12, #1]
	ldr r0, =str_jhr				// gleicher Vorgang fuer das Jahr
	bl	echo_input
	strb r0, [r12, #2]
	
	mov r0, #0
	strb r0, [r12, #5]				// Sekunden auf 0 setzen (Ausrichtung der Uebertragung an vollen Minuten)	
	bl reset_tsr
	bl put_curr_time				// Datum und Zeit ausgeben
	str r9, [r11]					// Setze Flag fuer die Uebertragung, so wird direkt eine Uebertragung mit den neuen Werten gestartet
	
	b 	main_loop					// zurueck zum Anfang

/* Unterprogramme und ISRs */	

/*
 * UP um PORTA auf low zu setzen.
 *
 * Parameter: keine	
 * Rueckgabe: Keine
 */
.thumb_func
toggle_output_low:
	ldr r0, =E4						
	ldr r1, =PTA6
	mov r2, #0
	str r2, [r0]
	str r2, [r1]
	bx lr

/*
 * UP um PORTA auf high zu setzen.
 *
 * Parameter: keine	
 * Rueckgabe: Keine
 */
.thumb_func
toggle_output_high:
	ldr r0, =E4						
	ldr r1, =PTA6
	mov r2, #1
	str r2, [r0]
	str r2, [r1]
	bx lr
	
/*
 * UP zur Berechnung des BCD das aktuellen Datums und der Uhrzeit.
 *
 * Parameter: Keine.	
 * Rueckgabe: In r0 wird die Zahl fuer die aktuelle Zeit im BCD Format mit Paritaetsbit zurueckgegeben.
 *			  In r1 wird die Zahl fuer das Datum im BCD Format mit Paritaetsbit zurueckgegeben.	
 *
 */
.thumb_func
curr_datetime:
	push {r4,r5,r6,lr}

	// Die Stunden werden umgerechnet und die Paritaet geprueft
	ldr r1, =date_time
	ldrb r0, [r1, #3]
	bl bcd_from_byte
	mov r4, r0
    bl check_parity   
    lsl r0, r0, #6
    orr r0, r4, r0    
    mov r5, r0
    lsl r5, r5, #8
    
    // Die Minuten werden umgerechnet und die Paritaet geprueft
	ldr r1, =date_time
	ldrb r0, [r1, #4]
	bl bcd_from_byte
	mov r4, r0
    bl check_parity    
    lsl r0, r0, #7
    orr r0, r4, r0
    orr r5, r5, r0
    
    // Die Tage werden umgerechnet 
	ldr r1, =date_time
	ldrb r0, [r1]
	bl bcd_from_byte
	mov r6, r0
	
	// Der Wochentag wird umgerechnet 
    mov r0, #WEDNESDAY
    lsl r0, r0, #6
    orr r6, r6, r0
    
    // Die Monate werden umgerechnet 
	ldr r1, =date_time
	ldrb r0, [r1, #1]
	bl bcd_from_byte
    lsl r0, r0, #9
    orr r6, r6, r0 
    
    // Die Jahrzehnte werden umgerechnet und schliesslich die Paritaet des Datums geprueft
	ldr r1, =date_time
	ldrb r0, [r1, #2]
	bl bcd_from_byte
    lsl r0, r0, #14
    orr r6, r6, r0   
    mov r0, r6
    bl check_parity    
    lsl r0, r0, #22
    orr r1, r6, r0   
    mov r0, r5
  
    pop {r4,r5,r6,pc}

/*
 * UP zur Berechnung des BCD eines uebergebenen Bytes.
 *
 * Parameter: In r0 wird das Byte uebergeben dessen BCD berechnet werden soll.
 * Rueckgabe: In r0 wird das Byte zurueckgegeben, das den BCD des Eingabebytes enthaelt.
 */
.thumb_func
bcd_from_byte:
	push {r4,lr}

	mov r1, #0          	// Initialisiere r1, um das Zwischenergebnis zu speichern
	mov r2, #10				// Vorbelegen von r2 mit 10 zur spaeteren Division

    udiv r3, r0, r2 		// Teile geladenen Wert durch 10 (Zehnerstelle)
    mls r4, r3, r2, r0 		// Berechne den Rest aus letzter Berechnung (Einerstelle)

    orr r1, r1, r3   		// Trage Zehnerstelle in Ergebnisregister
    lsl r1, r1, #4			// Schiebe Ergebnisregister nach links, um Platz zu machen für Einerstelle
    orr r1, r1, r4			// Trage Einerstelle in Ergebnisregister      
         
    mov r0, r1				// Uebergebe Ergebnis nach r0 zur Kontrolle
  
    pop {r4,pc}

/*
 * UP zur Berechnung der Parität einer 32 Bit Eingabe durch schrittweise XOR-Operationen.
 * Hierbei wird davon ausgegangen, dass eine gerade Paritaet vorliegen soll, gemaess dem
 * DCF77 Signal.
 *
 * Parameter: Eine 32 Bit Zahl wird in r0 uerbergeben, deren Paritaet berechnet werden soll.
 * Rueckgabe: Es wird ein Paritaetsbit in r0 zurueckgegeben (entweder 1 oder 0) 
 */
.thumb_func
check_parity:
    mov r1, r0        		// Kopiere die Eingabezahl nach R1

    eor r1, r1, r1, lsr #1  // XOR mit der Zahl, um um eins nach rechts verschobene Bits
    eor r1, r1, r1, lsr #2  // XOR mit der Zahl, um um zwei nach rechts verschobene Bits
    eor r1, r1, r1, lsr #4  // XOR mit der Zahl, um um vier nach rechts verschobene Bits
    eor r1, r1, r1, lsr #8  // XOR mit der Zahl, um um acht nach rechts verschobene Bits
    eor r1, r1, r1, lsr #16 // XOR mit der Zahl, um um sechzehn nach rechts verschobene Bits

    and r0, r1, #1    		// Extrahiere den letzten Bit von R1 als Paritätsbit
    bx lr             		// Rueckkehr von der Unterroutine

/*
 * Gibt den Text (Zeiger in r0) aus und liest einen zweistelligen Dezimalwert ein, 
 * gibt ihn (zur Kontrolle) wieder aus, haengt einen Zeilenumbruch an
 * und gibt den Wert in r0 zurueck
 * Parameter: r0 = Zeiger auf Text
 * Rueckgabe: eingelesener Wert
 */		
.thumb_func
echo_input:
	push {r4,lr}
	bl	uart_putString				// uebergebenen String ausgeben
	bl	uart_getByteBase10			// einen zweistelligen Dezimalwert einlesen
	mov r4, r0						// sichern
	bl	uart_putByteBase10			// zur Kontrolle ausgeben
	mov	r0, #LF						// neue Zeile
	bl	uart_putChar				// ausgeben
	mov r0, r4						// gesicherten Wert zurueckgeben
	pop {r4,pc}

/*
 * Setzt den Wert im Sekundenzaehlregister(TSR) auf 0 zurueck.
 *
 * Parameter: keine
 * Rueckgabe: keine
 */		
.thumb_func
reset_tsr:
	mov r0, #0						// Lade genutzte Werte vor
	mov r1, #1
	ldr r2, =RTC_SR_TCE				// BBA des TCE Bits im SR Register, um Zaehler zu de-/aktivieren
	ldr r3, =RTC_TSR				// Lade Adresse des Sekundenzaehlregisters (TSR)	
	str r0, [r2]					// Schalte den Zaehler aus
	str r0, [r3]					// Setze den Wert des Zaehlregisters auf 0
	str r1, [r2]					// Schalte den Zaehler ein	
	bx lr							// Springe zurueck

/*
 * Inkrementiert zunaechst nur die Minuten, bei einem Ueberlauf auch die jeweils naechsthoehere Einheit
 * Parameter: keine
 * Rueckgabe: keine
 */		
.thumb_func
inc_datetime:
	ldr r1, =date_time				// Zeiger auf das Array laden

	ldrb r0, [r1, #5]				// Sekunden laden
	add	r0, r0, #1					// inkrementieren
	cmp	r0, #MAX_MI					// mit Maximum vergleichen
	it hs							// bedingte Ausfuehrung
	movhs r0, #0					// Maximum erreicht, Reset-Wert laden 
	strb r0, [r1, #5]				// Minuten speichern
	blo inc_datetime_end			// Sprung zum Ende, wenn kein Ueberlauf

	ldrb r0, [r1, #4]				// Minuten laden
	add	r0, r0, #1					// inkrementieren
	cmp	r0, #MAX_MI					// mit Maximum vergleichen
	it hs							// bedingte Ausfuehrung
	movhs r0, #0					// Maximum erreicht, Reset-Wert laden 
	strb r0, [r1, #4]				// Minuten speichern
	blo inc_datetime_end			// Sprung zum Ende, wenn kein Ueberlauf

	ldrb r0, [r1, #3]				// Stunden laden
	add	r0, r0, #1					
	cmp	r0, #MAX_H	
	it hs						
	movhs r0, #0 
	strb r0, [r1, #3]
	blo inc_datetime_end

	ldrb r0, [r1]					// Tag laden
	add	r0, r0, #1				
	cmp	r0, #MAX_D				
	it hs						
	movhs r0, #1	 
	strb r0, [r1]	
	blo inc_datetime_end

	ldrb r0, [r1, #1]				// Monat laden
	add	r0, r0, #1				
	cmp	r0, #MAX_MO				
	it hs						
	movhs r0, #1	 
	strb r0, [r1, #1]
	blo inc_datetime_end

	ldrb r0, [r1, #2]				// Jahr laden
	add	r0, r0, #1	
	cmp	r0, #MAX_Y	
	it hs			
	movhs r0, #0	 
	strb r0, [r1, #2]

inc_datetime_end:
	bx lr

/*
 * Gibt Datum und Zeit auf dem Terminal aus
 * Parameter: keine
 * Rueckgabe: keine
 */		
.thumb_func
put_curr_time:
	push {r4,lr}		
	ldr	r4, =date_time		
	ldrb r0, [r4, #3]				// Stunde
	bl	out_leading0	
	mov	r0, #COLON					// Doppelpunkt
	bl	uart_putChar	
	ldrb r0, [r4, #4]				// Minute
	bl	out_leading0	
	mov	r0, #COLON					// Doppelpunkt
	bl	uart_putChar	
	ldrb r0, [r4, #5]				// Sekunde
	bl	out_leading0	
	mov	r0, #LF						// neue Zeile
	bl	uart_putChar	
	pop	{r4,pc}

/*
 * Gibt Datum und Zeit auf dem Terminal aus
 * Parameter: keine
 * Rueckgabe: keine
 */		
.thumb_func
put_datetime:
	push {r4,lr}	
	ldr r0, =str_weekday
	bl uart_putString	
	ldr	r4, =date_time
	ldrb r0, [r4], #1				// Tag 
	bl	out_leading0
	mov	r0, #DOT					// Punkt
	bl	uart_putChar
	ldrb r0, [r4], #1				// Monat
	bl	out_leading0
	mov	r0, #DOT					// Punkt
	bl	uart_putChar
	mov	r0, #20						// Jahrtausend 
	bl	uart_putByteBase10
	ldrb r0, [r4], #1				// Jahr (kurz)
	bl	out_leading0	
	mov	r0, #SPACE					// Leerzeichen
	bl	uart_putChar	
	ldrb r0, [r4], #1				// Stunde
	bl	out_leading0
	mov	r0, #COLON					// Doppelpunkt
	bl	uart_putChar
	ldrb r0, [r4], #1				// Minute
	bl	out_leading0
	ldr r0, =str_clock
    bl uart_putString
	pop	{r4,pc}
	
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
 * Initialisiert den PIT
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
	ldr r1, =PIT_COUNT_100 
	str r1, [r0]
	ldr r0, =PIT_TCTRL1
	mov r1, #PIT_TCTRL1_VAL			// PIT1: aktivieren, IRQs aktiv 
	str r1, [r0]
 	bx lr

/*
 * PIT-ISR (Interrupt Service Routine)
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
	
	ldr r0, =start_tra				// Lade genutzte Werte vor
	mov r1, #1
	str r1, [r0]
	
	bx lr
	
/*** Datenbereich (ab 0x20000000) ***/
.data
pit_flag: .word 0									// Flag fuer die Erzeugung der Pulse mit dem PIT1
user_flag: .word 0									// Flag, das im Sekundeninterrupt gesetzt wird
display: .word 1									// Eine Variable, um anzuzeigen, ob die Zeit aktuell angezeigt werden soll oder nicht (0 = Stop, 1 = Anzeige)
start_tra: .word 0									// Eine Variable, die anzeigt, ob 60 Sekunden vergangen sind und eine Uebertragung gestartet werden kann.

date_time: .byte 01,01,14,0,0,0						// Tag, Monat, Jahr, Stunde, Minute, Sekunden

str_weekday: .asciz "Mi., "
str_clock: .asciz " Uhr\n"
str_reset: .asciz "Sekunden zurueckgesetzt\n"
str_display_on: .asciz "Anzeige an\n"
str_display_off: .asciz "Anzeige aus\n"
str_skip_time: .asciz "Uhr vorgestellt\n"
str_print_date_time: .asciz "Drucke hier das Datum, dass uebertragen werden soll.\n"
str_std: .asciz "Stunde eingeben (hh): "
str_min: .asciz "Minute eingeben (mm): "
str_tag: .asciz "Tag eingeben (dd): "
str_mon: .asciz "Monat eingeben (mm): "
str_jhr: .asciz "Jahr eingeben (jj): "
