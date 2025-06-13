/************************************************************
Versuch: 6-1
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 45 Stunden
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

// Konstanten fuer den PIT1 (Erzeugung des Zeitintervalles)
.equ SIM_SCGC6,	 	0x4004803C
.equ SCR_VTOR,		0xE000ED08		// Register für die Interrupt-Vektor-Tabelle (IVT)
.equ PIT_MCR,       0x40037000
.equ PIT_LDVAL1,    0x40037110
.equ PIT_TCTRL1,    0x40037118
.equ PIT_TFLG1,     0x4003711C
.equ NVIC_ISER2, 	0xe000e108
.equ NVIC_ICPR2, 	0xe000e288

__BBREG SIM_PIT, SIM_SCGC6, 23					// Bit-Band-Alias-Adresse für den PIT im SIM-Register
__BBREG PIT_TCTRL1_TEN, PIT_TCTRL1, 0			// BBA des Bit 0 des PIT_TCTRL1 Registers des PIT Modules (Timer Enable)

.equ PIT1_IRQ_OFS,	0x154			// Interrupt Request Offset für PIT1
.equ NVIC_ISER2_MASK, 0x8800020     // Bit 27 (Port E), Bit 23(Port A), Bit 5 (PIT1) - Bitposition für PIT1, Port A und Port E in NVIC-Registern
.equ PIT_COUNT, 30001000			// ERKLAERUNG EINFUEGEN!!!!!!!!!!!!!!
.equ PIT_MCR_VAL, 0					// MDIS = 0, FRZ = 0
.equ PIT_TCTRL1_VAL, 3				// CHN = 0, TIE = 1, TEN = 1

// Konstanten fuer die Tasten SW1 und SW2
.equ GPIO_IRQ_PE_SET, 0xA0103	// GPIO-Modus, IRQ (fallende Flanke), Pull-Up-Widerstand

.equ PORTA_PCR19,   0x4004904C
.equ PORTE_PCR26,   0x4004d068

.equ GPIOA_PDDR, 	0x400ff014
.equ GPIOA_PDIR, 	0x400ff010

.equ GPIOE_PDDR, 	0x400ff114
.equ GPIOE_PDIR, 	0x400ff110

__BBREG	PDDR_SW1, GPIOA_PDDR, 19
__BBREG	PDDR_SW2, GPIOE_PDDR, 26

__BBREG	SW1, GPIOA_PDIR, 19
__BBREG	SW2, GPIOE_PDIR, 26

__BBREG SIM_PORTA, SIM_SCGC5, 9
__BBREG SIM_PORTE, SIM_SCGC5, 13

__BBREG	SW1_CIF, PORTA_PCR19, 24
__BBREG	SW2_CIF, PORTE_PCR26, 24

// IVT-Offsets fuer PIT, SW1 und SW2
.equ IVT_PIT1, 0x154
.equ IVT_PTA, 0x19c					// IVT-Offsets fuer Port A Interrupt (hier ist nur der SW1 aktiv)
.equ IVT_PTE, 0x1Ac					// IVT-Offsets fuer Port E Interrupt (hier ist nur der SW2 aktiv)

// Konstanten fuer das SPI und Thermometer DS1722
.equ SIM_SCGC3, 0x40048030			// Adresse des SIM Registers an dem das SPI2 angeschlossen ist
.equ SIM_SCGC5, 0x40048038			// Adresse des SIM Registers mit dem Port D (hier ist das Thermometer angeschlossen) initialisiert werden kann
__BBREG SIM_SPI2, SIM_SCGC3, 12
__BBREG SIM_PORTD, SIM_SCGC5, 12

.equ PORTD_PCR12, 0x4004c030
.equ PORTD_PCR13, 0x4004c034
.equ PORTD_PCR14, 0x4004c038
.equ PORTD_PCR15, 0x4004c03c

.equ ALT2_SPI2, 0x200 				// Alternative 2 fuer SPI2 Initialisierung im PCR (siehe Tabelle K60 Handbuch Seite 248/249)

// SPI Adressen
.equ SPI2_MCR, 	 0x400ac000
.equ SPI2_CTAR0, 0x400ac00c			
.equ SPI2_SR, 	 0x400ac02c
.equ SPI2_RSER,  0x400ac030
.equ SPI2_PUSHR, 0x400ac034			
.equ SPI2_POPR,  0x400ac038

// Einzelne Bit in den Adressen (Erklaerungen hinzufuegen)
__BBREG SPI2_MCR_FRZ, SPI2_MCR, 27
__BBREG SPI2_MCR_DIS_TXF, SPI2_MCR, 13
__BBREG SPI2_MCR_DIS_RXF, SPI2_MCR, 12
__BBREG SPI2_MCR_HALT, SPI2_MCR, 0
__BBREG SPI2_SR_TCF, SPI2_SR, 31
__BBREG SPI2_SR_EOQF, SPI2_SR, 28

// SPI Initialisierungswerte
.equ MCR_INIT,   0x80000001			// Master Mode aktiviert und Transfers gestoppt (FIFOs müssen ausgeschaltet werden, nachdem einmal geschrieben wurde)
.equ CTAR0_INIT, 0x7e441117			// DBR = 0, FMSZ = 1111 = 16 Bit pro Frame, CPOL = 1, CPHA = 1, LSBFE = 0 (MSB wird zuerst uebertragen), PCSSCK = 01,
									// PASC = 00, PDT = 01, PBR = 00, CSSCK = 0001, ASC = 0001, DT = 0001, BR = 0111
/*
PBR, DBR und BR wurden so gewaehlt, da (vgl. Formel im K60 Handbuch, S.1417)

(f_SYS/PBR) x ((1 + DBR)/BR) = (25Mhz/2) x ((1 + 0)/128) = 97,65625kHz (ca 100kHz)
*/									
.equ RSER_INIT,  0					// Hier wird alles auf 0 gesetzt, da DMA und Interrupts ausgestellt werden sollen.

// DS1722 Adressen
.equ DS1722_READ_MSB, 0x08020200    // EOQ, CS1, Adresse von MSB
.equ DS1722_READ_LSB, 0x08020100    // EOQ, CS1, Adresse von LSB
.equ DS1722_READ_CON, 0x08020000    // EOQ, CS1, Adresse von MSB
.equ DS1722_WRITE_CON, 0x08028000   // EOQ, CS1, Adresse von MSB

// Konstanten fuer die Brechnung der Aufloesung (e0, e2, e4, e6, e8)
.equ TOO_LOW_RES, 0xde				// Zu niedrige Aufloesung (wird als untere Grenze verwendet)
.equ TOO_HIGH_RES, 0xea				// Zu hohe Aufloesung (wird als obere Grenze verwendet)
.equ MIN_RES, 0xe0					// Maximale Aufloesung, falls ein Ueberlauf stattfindet
.equ MAX_RES, 0xe8					// Minimale Aufloesung, falls ein Unterlauf stattfindet

.equ WAIT_TIME_TCF, 1000			// Es wird in einer Schleife auf das TCF Flag gewartet. Tritt ein Fehler auf, wird eine Meldung ausgegeben 

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init					// UART initialisieren
	
	mov r8, #0						// Register vorbelegen mit 0
	mov r9, #1						// Register vorbelegen mit 1
	mov r10, #MAX_RES				// Register mit Intialwert fuer die Aufloesung belegen
	ldr r11, =mod					// Register mit Adresse von mod Variable (fuer die Taster) vorbelegen
	ldr r12, =pit_flag				// Register mit Adresse von PIT Flag vorbelegen

//////////////////////////// Konfiguration von Port D (hier ist das SPI2 Modul angeschlossen) 

	ldr r0, =SIM_PORTD 				// Den Takt fuer Port D aktivieren
	str r9, [r0]
	ldr r0, =PORTD_PCR12 			// Setze Pins 12, 13, 14 und 15
	ldr r1, =PORTD_PCR13			// auf Alternative 2. An diese Pins ist
	ldr r2, =PORTD_PCR14			// das DS1722 angeschlossen
	ldr r3, =PORTD_PCR15			
	mov r4, #ALT2_SPI2				
	str r4, [r0]					// Pin 12 -> CLK (Clock Singal vom Master)
	str r4, [r1]					// Pin 13 -> MOSI (Main Out, Sub In)	
	str r4, [r2]					// Pin 14 -> MISO (Main In, Sub Out)
	str r4, [r3]					// Pin 15 -> CS1 (ist mit Chip Enable vom DS1722 verbunden)
	
	ldr r0, =SIM_SPI2				// Den Takt fuer SPI2 aktivieren
	str r9, [r0]

//////////////////////////// Konfiguration des SPI2 Modules

    // MCR schreiben (0x80000001)
	ldr r0, =SPI2_MCR
	ldr r1, =MCR_INIT
	str r1, [r0]

    // MCR FIFOs deaktivieren (seperat, da zuerst die MDIS = 0 gesetzt werden muss)
	ldr r0, =SPI2_MCR_DIS_TXF
	str r9, [r0]
	ldr r0, =SPI2_MCR_DIS_RXF
	str r9, [r0]
	
    // CTAR0 schreiben (0x3e441117)
	ldr r0, =SPI2_CTAR0
	ldr r1, =CTAR0_INIT
	str r1, [r0]
		
    // RSER schreiben (0)
	ldr r0, =SPI2_RSER
	ldr r1, =RSER_INIT
	str r1, [r0]
	
    // SPI2 Uebertragung starten
	ldr r1, =SPI2_SR_EOQF			// Schreibe 0 in EOQF
	str r8, [r1]
	ldr r1, =SPI2_MCR_FRZ			// Schreibe 0 in FRZ
	str r8, [r1]
    ldr r1, =SPI2_MCR_HALT          // Schreibe 0 in HALT
	str r8, [r1]
	
	// Schreibe den initialen Wert in die Konfiguration des DS1722 (Übergabe 0xE8)
	mov r0, r10
	bl ds1722_write_config
	
//////////////////////////// Konfiguration von PIT1, SW1 und SW2

	// Takt fuer die benutzten Module aktivieren
	ldr r0, =SIM_PORTA
	str r9, [r0]
	ldr r0, =SIM_PORTE
	str r9, [r0]
	ldr r0, =SIM_PIT
	str r9, [r0]
	
	// GPIOE-Pin konfigurieren
	ldr r1, =GPIO_IRQ_PE_SET 	// GPIO-Modus mit IRQ (fallende Flanke) und Pull-Up-Widerstand 	
	ldr r0, =PORTA_PCR19 		// fuer SW1
	str r1, [r0]				// festlegen
	
	ldr r1, =GPIO_IRQ_PE_SET 	// GPIO-Modus mit IRQ (fallende Flanke) und Pull-Up-Widerstand 	
	ldr r0, =PORTE_PCR26 		// fuer SW2
	str r1, [r0]				// festlegen
	
	ldr r0, =PDDR_SW1			// Datenrichtung der GPIO-Pins festlegen
	str r8, [r0]				// Eingaenge (SW1 und SW2)
	ldr r0, =PDDR_SW2
	str r8, [r0]

    // Adressen der ISRs fuer PIT0, PIT1 und Port E in die IVT eintragen
	ldr r0, =SCR_VTOR
	ldr r1, [r0]
	ldr r0, =isr_port_a
	str r0, [r1, #IVT_PTA]
	ldr r0, =isr_port_e
	str r0, [r1, #IVT_PTE]
	ldr r0, =isr_pit1
	str r0, [r1, #IVT_PIT1]
	
	// PIT-Modul konfigurieren
	ldr r0, =PIT_MCR
	str r9, [r0]					// R9=1 -> FRZ=1, MDIS=0 (PIT stopped in Debug mode, PIT-Clock enabled)
		
    // PIT1 auf eine Sekunde einstellen
	ldr r0, =PIT_LDVAL1
	ldr r1, =PIT_COUNT				// Der Wert ist hier 30001000 (Erklaerung siehe im .data Bereich zusammen mit den anderen Werten)
	str r1, [r0]

    // PIT1 konfigurieren
	mov r1, #PIT_TCTRL1_VAL			// Interrupt aktiviert, Timer aktiviert
	ldr r0, =PIT_TCTRL1
	str r1, [r0]
	
	ldr r0, =NVIC_ICPR2				// Pending (haengende) IRQs zu PIT1, Port A und Port E im NVIC loeschen
	ldr r1, =NVIC_ISER2_MASK		// Bits für PIT1-IRQ, Port A-IRQ und Port E-IRQ in den NVIC-Registern
	str r1, [r0]
	ldr r0, =NVIC_ISER2				// IRQs zu PIT1, Port A und Port E im NVIC aktivieren
	str r1, [r0]					// R1 hat noch den Wert (NVIC_ISER2_MASK), also nicht neu laden
	
//////////////////////////// Start des Hauptloops, Beginn mit Auslesen von Temperaturen
	
main_loop:
	ldrb r0, [r12]					// Flag laden
	cmp	r0, #1						// Benutzerflag = Eins? 
	bne	main_loop					// Nein -> weiter warten
	
	strb r8, [r12]					// PIT Flag zuruecksetzen	

	bl ds1722_read_temp				// Springe ins UP, um die aktuelle Temperatur zu lesen

	bl print_temp					// Springe ins UP, um die aktuelle Temperatur auszugeben
		
	ldr r1, [r11]					// Wurde deine Taste gedrueckt?
	cmp r1, #1						// Wenn ja und es ist SW1,
	beq sw1_pressed					// springe entsprechend
	cmp r1, #2						// Wenn ja und es ist SW2,
	beq sw2_pressed					// springe entsprechend
		
	b main_loop						// zurueck zum mainloop	
	
sw1_pressed: 						// sw1, schwarze Taste gedrueckt
	add r10, r10, #2				// Erhoehe Aufloesung auf naechste Stufe
	cmp r10, #TOO_HIGH_RES			// Vergleiche, ob Wert zu hoch ist. Ist es e8 oder kleiner
	bne update						// Springe weiter
	mov r10, #MIN_RES				// Sonst setze die aktuelle Aufloesung auf das Minimum (e0 = 8 Bit)
	b update						// Springe weiter

sw2_pressed: 						// sw2, gruene Taste gedrueckt
	sub r10, r10, #2				// Verringere Aufloesung auf naechste Stufe
	cmp r10, #TOO_LOW_RES			// Vergleiche, ob Wert zu niedrig ist. Ist es e0 oder groesser
	bne update						// Springe weiter
	mov r10, #MAX_RES				// Sonst setze die aktuelle Aufloesung auf das Maximum (e8 = 12 Bit)
	
update:
	str r8, [r11]					// mod (Adresse in r11) Variable zuruecksetzen (= 0)

	ldr r0, =str_res				// Stringausgabe fuer die Terminal Ausgabe
	bl uart_putString

	ubfx r4, r10, #0, #4			// Index der neuen Aufloesung fuer String und neuen Zeitwert
	lsr r4, r4, #1					// Speichern des neuen Index in r5

	ldr r1, =str_table_res			// Lade die Adresse der Tabelle mit den Aufloesungsstrings aus dem Speicher
	ldr r0, [r1, r4, lsl #2]		// Lade und uebergebe den dem Index entsprechenden String
	bl uart_putString				// Drucke String
		
	mov r0, r10						// Aendere Aufloesung mit neuem Wert
	bl ds1722_write_config

	ldr r0, =PIT_TCTRL1_TEN			// Timer disable
	str r8, [r0] 
	ldr r1, =PIT_LDVAL1				// Lade Adresse des PIT1 Startwertes
	ldr r2, =table_pit_time			// Lade die Adresse der Tabelle mit den Zeitwerten aus dem Speicher
	ldr r3, [r2, r4, lsl #2]		// Lade die Adresse des Zeitwertes, der den oben berechneten Index hat, aus der Tabelle
	ldr r2, [r3]					// Lade den Zeitwert
	str r2, [r1]					// Speichere den neuen Zeitwert an die Adresse des PIT1 Startwertes
	str r9, [r0]					// Timer enable

	b main_loop						// zurueck zum main_loop

/*
 * Schreibt den uebergebenen Wert in das Konfigurationsregister des DS1722 Thermometers. Dieser 
 * wird uebergeben und dann wird zunaechst ein fuer das Schreiben in Konfigurationsegister 
 * vorgesehener Wert mit dem uebergebenen Wert verodert und dann in das PUSHR Register 
 * geschrieben.
 *
 * Parameter: In r0 wird der Wert uebergeben, der in das Register geschrieben werden soll. 
 * Rueckgabe: keine
 */
.thumb_func
ds1722_write_config:
	push {r4,lr}					// Sichere Register
	mov r4, r0						// Uebergabewert sichern
		
	ldr r1, =DS1722_WRITE_CON		// Lade den Wert fuer das PUSHR Register zum schreiben des Konfigurationsregisters (Erklaerung fuer den Wert s.o.)
	orr r1, r1, r4					// mit dem uebergebenen Wert verodern und
	
	ldr r0, =SPI2_PUSHR				// nach PUSHR schreiben
	str r1, [r0]

	bl wait_for_tcf					// Springe ins UP, um auf TCF zu warten

    pop {r4,pc}						// Stelle Register wieder her und springe zurueck


/*
 * In diesem UP wird die Temperatur aus dem DS1722 gelesen. Nach dem Vorladen der Adresse des
 * PUSHR Registers wird zuerst die Adresse des Registers fuer das MSB geladen (Erklaerung
 * des Wertes s.o.). Danach wird das Ergebnis in r5 zwischengespeichert und es wird das LSB
 * auslesen (mit entsprechender Adresse). Anschliessend werden beide Werte zu einer Zahl 
 * xxxx_VVN0 zusammengefuegt und schliesslich wird dieser Wert in r0 zurueckgegeben.
 *
 * Parameter: keine
 * Rueckgabe: In r0 wird die gemessene Temperatur zurueckgegeben.
 */
.thumb_func
ds1722_read_temp:
	push {r4,r5,lr}					// Sichere Register
	
	ldr r4, =SPI2_PUSHR				// Vorbelegen mit Adresse von PUSHR Register
	
	ldr r0, =DS1722_READ_MSB		// Adresse von MSB (0x0200) verODERn mit Bit 17 und EOQ
	str r0, [r4]					// nach PUSHR schreiben

	bl wait_for_tcf					// Springe ins UP, um auf TCF zu warten 
	
	mov r5, r0						// Rueckgabewert von TCF_Abwarten sichern (MSB des gemessenen Wertes)
	
	ldr r0, =DS1722_READ_LSB		// Adresse von LSB (0x0100) verODERn mit Bit 17 und EOQ
	str r0, [r4]					// nach PUSHR schreiben
	
	bl wait_for_tcf					// Springe ins UP, um auf TCF zu warten 
		
	mov r4, r0						// Rueckgabewert von TCF_Abwarten sichern (LSB des gemessenen Wertes)
	ubfx r4, r4, #0, #8				// Betrachte nur die ersten 8 Bit
	
	lsl r5, r5, #8					// Rueckgabewert von LSB und MSB verODERn (MSB LSL 8 Bit)
	orr r0, r5, r4					// Kombinierten Wert zurueckgeben
	
	pop {r4,r5,pc}					// Stelle Register wieder her und springe zurueck

/*
 * Beschreibung einfuegen (eventuell zugriff auf MCR zusammenfassen?????)
 *
 * Parameter: keine
 * Rueckgabe: keine
 */	
.thumb_func
ds1722_stop:
	mov r0, #0x1					// Vorbelegen mit 1
    ldr r1, =SPI2_MCR_HALT          // Schreibe 1 in HALT
	str r0, [r1]
	ldr r1, =SPI2_MCR_FRZ			// Schreibe 1 in FRZ
	str r0, [r1]
	ldr r1, =SPI2_SR_EOQF			// Schreibe 1 in EOQF
	str r0, [r1]
	bx lr							// Springe zurueck

/*
 * Ein UP, in dem auf das TCF Flag gewartet wird. Wird dieses gesetzt, so wird das Register
 * POPR ausgelesen, in dem sich dann im Kontext dieses Programmes die ausgelesenen Temperaturwerte
 * befinden. Anschliessend wird das TCF Flag zurueckgesetzt. Wird das TCF Flag nicht gesetzt wird
 * eine Fehlernachricht ausgegeben
 *
 * Parameter: keine
 * Rueckgabe: Es wird der Inhalt von POPR zurueckgegeben.
 */
.thumb_func
wait_for_tcf:
	push {lr}
	ldr r1, =SPI2_SR_TCF			// BBA von TCF laden
	mov r2, #WAIT_TIME_TCF			// Anzahl an Takten, die auf das TCF gewartet wird
	
wait_loop:
	ldr r0, [r1]					// Lade Wert von TCF
	cmp r0, #1						// Vergleiche TCF mit 1
	beq read_popr_set_tcf		    // Wenn 1, dann Schleife verlassen
	subs r2, r2, #1					// Dekrementiere den Zaehler
	bne wait_loop					// Ist der Zaehler noch nicht 0, springe zurueck

	ldr r0, =str_err				// Laeuft der Zaehler ab, dann gebe eine
	bl uart_putString				// Fehlermeldung auf das Terminal aus
	
	b skip							// und springe zum Ende des UPs
	
read_popr_set_tcf:
	ldr r2, =SPI2_POPR				// POPR auslesen (neuer Rueckgabewert)
    ldr r0, [r2]					// Rueckgabewert zurückgeben
             
    mov r2, #1
    str r2, [r1]					// TCF = 1 (zum Zuruecksetzen)

skip:
	pop {pc}

/*
 * Gibt die gemessene Temperatur auf dem Terminal aus
 * Parameter: r0 = Temperatur (0x0000VVN0)
 * Rueckgabe: keine
 */		
.thumb_func
print_temp:
	push {r4,lr}
	mov r4, r0						// Temperatur sichern
	
	lsr r0, r4, #8					// Vorkommastellen
	bl uart_putByteBase10			// ausgeben

	ubfx r2, r4, #4, #4				// Nachkommastellen separieren

	ldr r1, =str_table_comma		// Startadresse der Stringtabelle
	ldr r0, [r1, r2, lsl #2]		// Stringadresse mit Index laden 
	bl uart_putString				// und ausgeben
	
	pop {r4,pc}	

/*
 * ISR fuer SW1 (Port A)
 * Parameter: keine
 * Rueckgabe: keine
 *
 * Es wird wieder vereinfachend davon ausgegangen, dass ein IRQ an Port A ausschließlich von SW1 ausgeloest werden kann.
 *
 */		
.thumb_func 
isr_port_a: 					
	ldr r0, =SW1_CIF			// Bit-Band-Adresse des Interrupt-Flags fuer SW1
	mov r1, #1
	str r1, [r0]				// Flag loeschen

	ldr r0, =mod				// Setze Flag fuer SW1, um im Hauptprogramm anzuzeigen,
	str r1, [r0]				// dass die Taste SW1 gedrueckt wurde

	bx lr

/*
 * ISR fuer SW2 (Port E)
 * Parameter: keine
 * Rueckgabe: keine
 *
 * Es wird wieder vereinfachend davon ausgegangen, dass ein IRQ an Port E ausschließlich von SW2 ausgeloest werden kann.
 *
 */		
.thumb_func 
isr_port_e: 					
	ldr r0, =SW2_CIF			// Bit-Band-Adresse des Interrupt-Flags fuer SW2
	mov r1, #1
	str r1, [r0]				// Flag loeschen

	ldr r0, =mod				// Setze Flag fuer SW2,
	mov r1, #2					// um im Hauptprogramm anzuzeigen, dass die
	str r1, [r0]				// Taste SW2 gedrueckt wurde

	bx lr
		
/*
 * PIT-ISR (Interrupt Service Routine)
 *
 * Parameter: keine
 * Rueckgabe: keine
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
mod: .word 0

// Ausgabe fuer das Terminal												
str_res: .asciz "Die Aufloesung wurde geaendert. Die neue Aufloesung ist "

// Ausgabe im Fall eines Fehlers
str_err: .asciz "Es ist bei der Programmausfuehrung zu einem Fehler gekommen. Das Programm muss neu gestartet werden!"

// Tabelle der Adressen der Strings fuer die Wandlungszeiten
table_pit_time: .word time_8_bit, time_9_bit, time_10_bit, time_11_bit, time_12_bit

// Liste der Wandlungszeiten
time_8_bit: .word 1876000 		// 1875000 Takte max conversion time wegen 25000000 Takte = 1s ; 1000 Takte fuer Auslesen -> 1886000 Takte
time_9_bit: .word 3751000 		// 3750000 Grund genau wie oben -> 3760000 Takte
time_10_bit: .word 7501000   	// 7500000 Grund genau wie oben -> 7510000 Takte
time_11_bit: .word 15001000		// 15000000 Grund genau wie oben -> 15010000 Takte
time_12_bit: .word 30001000		// 30000000 Grund genau wie oben -> 30010000 Takte

// Tabelle der Adressen der Strings fuer die Nachkommastellen
str_table_comma: .word str_0, str_1, str_2, str_3, str_4, str_5, str_6, str_7, str_8, str_9, str_a, str_b, str_c, str_d, str_e, str_f

// Liste der Strings fuer die Nachkommastellen
str_0: .asciz ",0 gC\n" 
str_1: .asciz ",0625 gC\n" 
str_2: .asciz ",125 gC\n" 
str_3: .asciz ",1875 gC\n" 
str_4: .asciz ",25 gC\n" 
str_5: .asciz ",3125 gC\n" 
str_6: .asciz ",375 gC\n" 
str_7: .asciz ",4375 gC\n"
str_8: .asciz ",5 gC\n"
str_9: .asciz ",5625 gC\n"
str_a: .asciz ",625 gC\n" 
str_b: .asciz ",6875 gC\n"
str_c: .asciz ",75 gC\n"
str_d: .asciz ",8125 gC\n"
str_e: .asciz ",875 gC\n"
str_f: .asciz ",9375 gC\n"

// Tabelle der Adressen der Strings fuer die Aufloesung
str_table_res: .word str_8_bit, str_9_bit, str_10_bit, str_11_bit, str_12_bit

// Liste der Strings fuer die Aufloesung
str_8_bit: .asciz "8 Bit.\n" 
str_9_bit: .asciz "9 Bit.\n" 
str_10_bit: .asciz "10 Bit.\n" 
str_11_bit: .asciz "11 Bit.\n" 
str_12_bit: .asciz "12 Bit.\n"
