/************************************************************
Versuch: 3-2
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 50 Stunden
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

// Konstanten mit Adressen fuer PIT Konfiguration und PIT Interrupt Erzeugung (PIT1 und PIT2)
.equ SIM_SCGC6,	 	0x4004803C
.equ SCR_VTOR,		0xE000ED08		// Register für die Interrupt-Vektor-Tabelle (IVT)

.equ PIT_MCR,       0x40037000
.equ PIT_LDVAL1,    0x40037110
.equ PIT_LDVAL2,    0x40037120
.equ PIT_TCTRL1,    0x40037118
.equ PIT_TCTRL2,    0x40037128
.equ PIT_TFLG1,     0x4003711C
.equ PIT_TFLG2,     0x4003712C

.equ NVIC_ISER2, 	0xe000e108
.equ NVIC_ICPR2, 	0xe000e288

// Bit Band-Konstanten fuer PIT Konfiguration (PIT1 und PIT2)
__BBREG BB_SIM_PIT, SIM_SCGC6, 23				// Bit-Band-Alias-Adresse für den PIT im SIM-Register
__BBREG PIT_TCTRL1_TEN, 0x40037118, 0			// Berechnung der BBA des Bit 0 der Basisadresse des PIT_TCTRL1 Registers des PIT Modules (Timer Enable)
__BBREG PIT_TCTRL2_TEN, 0x40037128, 0			// Berechnung der BBA des Bit 0 der Basisadresse des PIT_TCTRL1 Registers des PIT Modules (Timer Enable)

// weitere Konstanten fuer PIT Konfiguration (PIT1 und PIT2)
.equ PIT1_IRQ_OFS,	0x154			// Interrupt Request Offset für PIT1
.equ PIT2_IRQ_OFS,	0x158			// Interrupt Request Offset für PIT2
.equ PIT1_NVIC_MASK, 1 << (69 % 32)	// Bitposition für PIT1-IRQ in NVIC-Registern (IRQ mod 32)
.equ PIT2_NVIC_MASK, 1 << (70 % 32)	// Bitposition für PIT2-IRQ in NVIC-Registern (IRQ mod 32)

.equ PIT_COUNT, 25000000			// 25000000	Takte bei 25 MHz => 1 Sekunde
.equ PIT_COUNT_DEBOUNCE, 125000		// 25000	Takte bei 25 MHz => 1 ms => 125000 sind 5ms
.equ PIT_MCR_VAL, 0					// MDIS = 0, FRZ = 0
.equ PIT_TCTRL1_VAL, 3				// CHN = 0, TIE = 1, TEN = 1
.equ PIT_TCTRL2_VAL, 2				// CHN = 0, TIE = 1, TEN = 0

// Konstanten fuer GPIO Port Konfiguration
.equ SIM_SCGC5, 0x40048038
.equ PCR_INIT, 0x100				// Konstante fuer einen Initialwert fuer die PCR Register (GPIO)
.equ PORTA_PCR10, 0x40049028		// Konstante fuer die Adresse von LED 3 im PCR
.equ PORTA_PCR11, 0x4004902c		// Konstante fuer die Adresse von LED 0 im PCR
.equ PORTA_PCR28, 0x40049070		// Konstante fuer die Adresse von LED 1 im PCR
.equ PORTA_PCR29, 0x40049074		// Konstante fuer die Adresse von LED 2 im PCR

.equ PORTA_PCR19, 0x4004904c		// Konstante fuer die Adresse von SW1 (schwarzer Knopf) im PCR
.equ PORTE_PCR26, 0x4004d068		// Konstante fuer die Adresse von SW2 (gruener Knopf) im PCR

.equ GPIOA_PCOR, 0x400ff008			// Konstante fuer die Adresse des Clear Output Registers
.equ GPIOA_PTOR, 0x400ff00c			// Konstante fuer die Adresse des Toggle Output Registers
.equ GPIOA_PDDR, 0x400ff014
.equ GPIOA_PDIR, 0x400ff010			// Konstante fuer die Adresse des Data Input Registers von Port A

.equ GPIOE_PDIR, 0x400ff110			// Konstante fuer die Adresse des Data Input Registers von Port E
.equ GPIOE_PDDR, 0x400ff114			// Konstante fuer die Adresse des Data Direction Registers von Port E

// weitere Konstanten fuer die GPIO Konfiguration
.equ LED0_BIT, 1 << 11      		// Konstante fuer das Bit von LED0(D7), das um 11 Stellen verschoben wird 
.equ LED1_BIT, 1 << 28       		// Konstante fuer das Bit von LED1(D8), das um 28 Stellen verschoben wird
.equ LED2_BIT, 1 << 29       		// Konstante fuer das Bit von LED2(D9), das um 29 Stellen verschoben wird
.equ LED3_BIT, 1 << 10       		// Konstante fuer das Bit von LED3(D11), das um 10 Stellen verschoben wird

.equ ALL_LED_ONE, 0x30000c00		// Konstante mit einer 1 an jeder Stelle an der an Port A ein LED angeschlossen ist

.equ PCR_INIT_SW2, 0x103			// Konstante fuer einen Initialwert fuer die PCR Register der Switches (GPIO, Pull/Select)

// Konstanten fuer das Einschalten der benutzten GPIO Ports im SIM
__BBREG SIM_SCGC5_PORTA, SIM_SCGC5, 9					// Berechnung der BBA des Bit 9 der Basisadresse des SCGC5 Registers des SIM (fuer Port A)
__BBREG SIM_SCGC5_PORTE, SIM_SCGC5, 13					// Berechnung der BBA des Bit 13 der Basisadresse des SCGC5 Registers des SIM (fuer Port E)
__BBREG GPIOA_PDIR_SW1, GPIOA_PDIR, 19
__BBREG GPIOE_PDIR_SW2, GPIOE_PDIR, 26

// allgemeine Konstanten
.equ LF, 0x0a						// Konstante fuer eine neue Zeile (Ascii-Code)
.equ CHAR_S, 's'				
.equ CHAR_PLUS, '+'
.equ CHAR_MINUS, '-'
.equ OF_INCR, 0x100					// Konstante fuer Ueberlaufbehandlung
.equ INIT_DECR, 0xff				// Konstante fuer Unterlaufbehandlung
.equ DEBOUNCE_DELAY, 41667 			// 8333333 ist ca 1 s -> 8333 ist ca 1 ms -> 41667 ist ca 5ms
.equ BUTTON_VALID, 0x3				// Konstante fuer eine Maske fuer die Gueltigkeitsbits der mod Variable
.equ BUTTON_PRESSED, 0xc				// Konstante fuer eine Maske fuer die "gedrueckt"-Bits der mod Variable
   
/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init					// UART initialisieren
	bl pit1_init					// PIT1 initialisieren
	bl pit2_init					// PIT2 initialisieren
	
	bl gpio_init					// GPIO initialisieren (LED und Taster initialisieren)
	
	ldr r12, =pit1_flag				// Adresse des Benutzerflags laden
	ldr r11, =counter				// Adresse der Zaehlervariable im Speicher
    ldr	r10, =running				// Zeiger auf das Start-/Stopp-Flag
    ldr r9, =direction				// Zeiger auf das Richtungsflag
    ldr r8, =mod					// Zeiger auf das mod Flag
    ldr r7, =PIT_TCTRL1_TEN			// Adresse des Timer Enable Bit des PIT1 Kontrollregisters
    ldr r6, =PIT_TCTRL2_TEN			// Adresse des Timer Enable Bit des PIT2 Kontrollregisters
    ldr r5, =GPIOA_PDIR_SW1			// Adresse des Data Input Registers des SW1
    ldr r4, =GPIOE_PDIR_SW2			// Adresse des Data Input Registers des SW2
    
    ldr r0, [r11]					// Ausgabe des initialen Counters auf das Terminal
    bl uart_putByte   				
    mov r0, #LF						// Ausgabe eines Zeilenvorschubes
    bl uart_putChar
    
/*
* Hier beginnt der Hauptloop des Programmes in dem der Zaehler inkrementiert oder dekrementiert
* wird und in dem Eingaben entgegen genommen werden. In jedem Durchgang werden erst die Taster
* geprueft und falls sie gedrueckt werden wird von hier ausgehend die entsprechende Reaktion 
* eingeleitet. Dann wird auf eine Eingabe im Terminal geprueft und entsprechend gehandelt. 
* Schliesslich wird der Zaehler erhoeht und der neue Stand ausgegeben, sowohl im Terminal 
* als auch auf der konfigurierten LED Ausgabe.
*/
main_loop:
    ldrb r1, [r5]					// Pruefe, ob der Taster SW1 gedrueckt ist
    cmp r1, #0						// Ist er nicht gedrueckt,
    bne sw1_not_pressed				// springe weiter

    ldr r1, [r8]					// Pruefe, ob das Bit 2 (steht fuer SW1 gedrueckt) von mod gleich 0 ist
    tst r1, #(1 << 2)  				// Ist das Bit 2 gesetzt, so wurde SW1 gedrueckt
    bne skip_inputs			  		// Wenn bereits gedrueckt, ueberspringe Eingabe

    orr r1, r1, #(1 << 2)			// Wenn noch nicht gedrueckt, setze auf gedrueckt
    str r1, [r8]					// durch das Setzen von Bit 2 von mod auf 1

    ldr r0, =DEBOUNCE_DELAY    		// Lade den Zaehlschleifenwert in R2
debounce_loop_sw1:
    subs r0, r0, #1                 // Verringere den Zaehler
    bne debounce_loop_sw1           // Wenn der Zaehler nicht null ist, wiederhole

    bl check_button_sw1				// Rufe ein UP auf um die Gueltigkeit des Knopfdruckes zu pruefen

sw1_not_pressed:
    ldrb r1, [r5]					// Pruefe, ob der Taster SW1 gedrueckt ist und
    cmp r1, #0						// ist er gedrueckt, 
    beq check_inputs				// springe zur Eingabeabfrage

    ldr r1, [r8]					// Lade aktuellen Wert von mod
    bic r1, r1, #(1 << 2)			// und loesche Bit 2 von mod (reset)
    str r1, [r8]

check_sw2:
    ldrb r1, [r4]					// Pruefe, ob der Taster SW2 gedrueckt ist
    cmp r1, #0						// Ist er nicht gedrueckt,
    bne sw2_not_pressed				// springe weiter

    ldr r1, [r8]					// Pruefe, ob das Bit 3 (steht fuer SW2 gedrueckt) von mod gleich 0 ist
    tst r1, #(1 << 3)  				// Ist das Bit 3 gesetzt, so wurde SW2 gedrueckt
    bne check_inputs		  		// Wenn bereits gedrueckt, ueberspringe Eingabe

    orr r1, r1, #(1 << 3)			// Wenn noch nicht gedrueckt, setze auf gedrueckt
    str r1, [r8]					// durch das Setzen von Bit 3 von mod auf 1

    mov r1, #1						// und in diesem Fall starten wir den Timer PIT2
    strb r1, [r6]					// der nach 5ms ein Interrupt ausloest

sw2_not_pressed:
    ldrb r1, [r4]					// Pruefe, ob der Taster SW2 gedrueckt ist und
    cmp r1, #0						// ist er gedrueckt,
    beq skip_inputs					// springe zur Eingabeabfrage

    ldr r1, [r8]					// Lade aktuellen Wert von mod
    bic r1, r1, #(1 << 3)			// und loesche Bit 3 von mod (reset)
    str r1, [r8] 

/*
* Ab hier wird geprueft, ob eine Eingabe vorliegt. Erst wird geprueft ob (durch einen Tastendruck)
* die mod Variable veraendert wurde und dann wird auf eine Eingabe auf dem Terminal geprueft.
*/	
check_inputs:
    ldr r1, [r8]					// Pruefe mod Variable und
    cmp r1, #0						// falls diese nicht Null ist
    bne check_switches				// springe zur Tasterpruefung, sonst gehe weiter

	bl uart_charPresent				// Check Input! Wurde ein Zeichen eingegeben?
	cbnz r0, check_terminal			// ja, pruefen
/*
* Das Pruefen der Eingabe kann uebersprungen werden (dies ist fuer den Fall, dass 
* Taster gedrueckt gehalten werden).
*/
skip_inputs:
	ldrb r0, [r10]					// Variable fuer Start/Stopp laden
	cmp	r0, #1						// laeuft der Zaehler?
	bne	main_loop					// nein, nur die Eingabe abfragen

	ldrb r0, [r12]					// Flag laden
	cmp	r0, #1						// Benutzerflag = Eins? 
	bne	main_loop					// Nein -> weiter warten
	
	mov r0, #0						// Setze eine Null, um das
	strb r0, [r12]					// Benutzerflag zurueck zu setzen

    ldr r0, [r11]					// Lade den aktuellen Wert des Counters    
    ldrb r1, [r9]					// und das Flag fuer die Richtung

    cmp r1, #1						// Zaehle entweder aufwaerts oder 
    beq incr_counter
    cmp r1, #0						// abwaerts basierend auf der Richtung
    beq decr_counter

incr_counter:
    add r0, r0, #1              	// Inkrementiere den Zaehler
    cmp r0, #OF_INCR           		// Ueberpruefe auf Ueberlauf
    bne store_curr					// Gibt es keinen Ueberlauf, srpinge weiter
    mov r0, #0                  	// Setze den Zaehler zurueck bei Ueberlauf
    b store_curr

decr_counter:
    sub r0, r0, #1              	// Dekrementiere den Zaehler
    cmp r0, #-1                 	// Ueberpruefe auf Unterlauf
    bne store_curr					// Gibt es keinen Unterlauf, springe weiter
    mov r0, #INIT_DECR          	// Setze den Zaehler auf 255 bei Unterlauf

store_curr:
    str r0, [r11]               	// Speichere den aktuellen Zaehlerwert zurück in den Speicher

    bl uart_putByte   				// Ausgabe des aktuellen Counters auf das Terminal
    mov r0, #LF						// Ausgabe eines Zeilenvorschubes
    bl uart_putChar
       
    ldr r0, [r11]					// Lade den aktuellen Zählerwert aus dem Speicher in r0, um ihn an das folgende UP zu uebergeben 
    bl map_bits_to_leds				// Aktualisiere die Anzeige des Counters durch die LEDs 

    b main_loop

check_switches:
    ldr r1, [r8]					// Lade aktuellen Wert der mod Variable
    and r2, r1, #BUTTON_VALID		// Schreibe die Bits 0 und 1 in r2 (Zur Weiterverarbeitung)
    and r1, r1, #BUTTON_PRESSED		// Schreibe die Bits 2 und 3 in r1 und lege
	str r1, [r8]					// diese im Speicher ab
    
    cmp r2, #1						// Pruefe ob das erste Bit gesetzt wurde (SW1) und
    beq ci_switch_dir				// wechsele zu entsprechendem Programmteil
    
    cmp r2, #2						// Pruefe ob das zweite Bit gesetzt wurde (SW2) und
    beq ci_stasto					// wechsele zu entsprechendem Programmteil  
    
    b	main_loop					// keine gueltige Eingabe, normal weitermachen
   
check_terminal:						
	bl	uart_getChar				// eingegebenes Zeichen einlesen
	cmp	r0, #CHAR_S					// war es ein 's'?
	beq	ci_stasto					// ja, verzeigen
	cmp r0, #CHAR_PLUS				// war es ein '+'?
	beq ci_plus						// ja, verzeigen
	cmp r0, #CHAR_MINUS				// war es ein '-'?
	beq ci_minus					// ja, verzeigen
	
	b	main_loop					// keine gueltige Eingabe, normal weitermachen
	
ci_stasto:
	mov r2, #0						// Fuer den Fall, dass gestoppt wird, kann der PIT1 Timer auch
	mov r3, #1      				// gestoppt werden und hiermit wieder gestartet werden	  

	ldrb r1, [r10]					// Variable fuer Start/Stopp laden
	cmp r1, #1						// mit eins (= Uhr laeuft) vergleichen
	ittee ne						// Bedingung vorgeben
	ldrne r0, =str_start			// entsprechenden String auswaehlen
	strbne r3, [r7]					// und entsprechenden Wert im 
	ldreq r0, =str_stopp			// Speicher ablegen
	strbeq r2, [r7]
	eor r1, r1, #1					// Variable umkehren
	strb r1, [r10]					// und zurueckschreiben
	bl	uart_putString				// gewaehlten String ausgeben
	
	b 	main_loop					// zurueck zum Anfang
	
ci_plus:
	ldrb r1, [r9]
	cmp r1, #1
	it eq
	beq main_loop					// Wird schon vorwaerts gezaehlt, springe zurueck zum Hauptloop
	ldr r0, =str_up
	eor r1, r1, #1					// Variable umkehren
	strb r1, [r9]					// und zurueckschreiben
	bl	uart_putString				// gewaehlten String ausgeben

	b 	main_loop					// zurueck zum Anfang
	
ci_minus:
	ldrb r1, [r9]
	cmp r1, #0
	it eq
	beq main_loop					// Wird schon rueckwaerts gezaehlt, springe zurueck zum Hauptloop
	ldr r0, =str_down
	eor r1, r1, #1					// Variable umkehren
	strb r1, [r9]					// und zurueckschreiben
	bl	uart_putString				// gewaehlten String ausgeben

	b 	main_loop					// zurueck zum Anfang

ci_switch_dir:
	ldrb r1, [r9]					// Lade den Wert der Running Variable
	eor r1, r1, #1					// Variable umkehren
	strb r1, [r9]					// und zurueckschreiben
	
	ldr r0, =str_dir_switched		// Gebe passenden String aus
	bl uart_putString
	
	b main_loop						// zurueck zum Anfang

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
 * Initialisiert den PIT2 (PITs wurden im SIM schon aktiviert (siehe pit1_init))
 * Parameter: keine
 * Rueckgabe: keine
 */		
.thumb_func
pit2_init:
	ldr r0, =SCR_VTOR				// Basisadresse der IVT
	ldr r1, [r0]					// laden
	ldr r0, =isr_pit2				// ISR fuer den PIT2 
	str r0, [r1, #PIT2_IRQ_OFS]		// in die IVT eintragen
	
	ldr r0, =NVIC_ICPR2				// Pending (haengende) IRQs zu PIT2 im NVIC loeschen
	mov r1, #PIT2_NVIC_MASK			// Bit für PIT2-IRQ in den NVIC-Registern
	str r1, [r0]
	ldr r0, =NVIC_ISER2				// IRQs zu PIT2 im NVIC aktivieren
	str r1, [r0]					// R1 hat noch den Wert (PIT1_NVIC_MASK), also nicht neu laden

	ldr r0, =PIT_MCR				
	mov r1, #PIT_MCR_VAL			// alle PITs einschalten, im Debug-Modus anhalten
	str r1, [r0]
	ldr r0, =PIT_LDVAL2				// initialen Zaehlwert setzen
	ldr r1, =PIT_COUNT_DEBOUNCE 
	str r1, [r0]
	ldr r0, =PIT_TCTRL2
	mov r1, #PIT_TCTRL2_VAL			// PIT2: noch nicht aktivieren, IRQs aktiv 
	str r1, [r0]
 	bx lr
 	
 	
/*
 * Initialisiert die GPIO Ports und zugehoerige Module fuer die LED Anzeige und die Switches
 * Parameter: keine
 * Rueckgabe: keine
 */		
.thumb_func
gpio_init:
	ldr r0, =SIM_SCGC5_PORTA	    // Lade Adresse eines Registers des SIM, um Port A zu aktivieren
    mov r1, #1					  	// Lade Aktivierungsbit
    strb r1, [r0]				  	// Aktiviere Port A im SIM
    
    ldr r0, =SIM_SCGC5_PORTE	    // Lade Adresse eines Registers des SIM, um Port E zu aktivieren
    strb r1, [r0]				  	// Aktiviere Port E im SIM
    
    ldr r0, =PORTA_PCR10			// Lade Adresse des PCR Registers von LED 3
    mov r1, #PCR_INIT				// Lade den Initialwert fuer die CRC Register
    str r1, [r0]					// und speichere diesen an die Adresse
    
    ldr r0, =PORTA_PCR11			// Lade Adresse des PCR Registers von LED 0
    str r1, [r0]					// und speichere den Initialwert an diese Adresse
    
    ldr r0, =PORTA_PCR28			// Lade Adresse des PCR Registers von LED 1
    str r1, [r0]					// und speichere den Initialwert an diese Adresse
    
    ldr r0, =PORTA_PCR29			// Lade Adresse des PCR Registers von LED 2
    str r1, [r0]					// und speichere den Initialwert an diese Adresse
    
    ldr r0, =PORTA_PCR19			// Lade Adresse des PCR Registers von LED SW1
    ldr r1, =PCR_INIT				// Lade den Initialwert fuer die CRC Register
    str r1, [r0]					// und speichere diesen an die Adresse
    
    ldr r0, =GPIOA_PDDR				// Lade Adresse des PDDR Registers
    ldr r1, =ALL_LED_ONE			// Hier soll an den entsprechenden Bits eine 1 geschrieben	
    str r1, [r0]					// werden, um die Pins auf Output einzustellen und eine 0 dahin, wo ein Input anliegt (Pin 19)
    
    ldr r0, =GPIOA_PTOR				// Lade Adresse des Toggle Output Registers
    str r1, [r0]					// Schalte alle LEDs zu Beginn des Betriebes aus
    
	ldr r0, =PORTE_PCR26			// Lade Adresse des PCR Registers von LED SW2
    ldr r1, =PCR_INIT_SW2			// Lade den Initialwert fuer die CRC Register mit aktiviertem Pull/Select
    str r1, [r0]					// und speichere diesen an die Adresse
  
    ldr r0, =GPIOE_PDDR				// Lade Adresse des PDDR Registers von Port E
    mov r1, #0						// Hier soll an ueberall eine 0 geschrieben werden, so	
    str r1, [r0]					// werden die Pins auf Input eingestellt

 	bx lr

/*
 * Unterprogramm zur Aktualisierung der LED Anzeige. Es wird der aktuellen Wert des Counters
 * uebergeben und so koennen die Bits des aktuellen Counterwertes auf die entsprechenden Bit
 * der LED Anzeige gemapt werden. Zuerst werden also die Bits gemapt und dann wird die Anzeige
 * zurueckgesetzt und dann direkt wieder mit dem neuen Wert fuer die Ausgabe beschrieben. Es
 * wird so vorgegangen, da es die Berechnung der aktuellen Werte ernorm vereinfacht, wenn immer
 * davon ausgegangen werden kann, dass sich die LEDs alle im Zustand "aus" befinden. Und da 
 * der Ausgabewert direkt wieder beschrieben wird, ist auf der Anzeige kein Unterschied bemerkbar.
 *
 * Parameter: aktueller Wert des Counters wird in r0 uebergeben
 * Rueckgabe: keine
*/
.thumb_func
map_bits_to_leds:
    mov r1, #0                    	// Initialisiere R1 mit 0

    tst r0, #1                    	// Map Bit 0 auf Bit 11; Teste Bit 0
    beq skip_bit0                 	// Wenn Bit 0 nicht gesetzt, überspringe
    orr r1, r1, #LED0_BIT         	// Setze Bit 11
skip_bit0:

    tst r0, #2                    	// Map Bit 1 auf Bit 28; Teste Bit 1
    beq skip_bit1                 	// Wenn Bit 1 nicht gesetzt, überspringe
    orr r1, r1, #LED1_BIT         	// Setze Bit 28
skip_bit1:

    tst r0, #4                    	// Map Bit 2 auf Bit 29; Teste Bit 2
    beq skip_bit2                 	// Wenn Bit 2 nicht gesetzt, überspringe
    orr r1, r1, #LED2_BIT         	// Setze Bit 29
skip_bit2:

    tst r0, #8                    	// Map Bit 3 auf Bit 10; Teste Bit 3
    beq skip_bit3                 	// Wenn Bit 3 nicht gesetzt, überspringe
    orr r1, r1, #LED3_BIT         	// Setze Bit 10
skip_bit3:
    ldr r2, =GPIOA_PCOR				// Lade Adresse des Clear Output Registers
    ldr r3, =ALL_LED_ONE			// Cleare die den LEDs entsprechenden Bits
    str r3, [r2]
    ldr r2, =GPIOA_PTOR				// Lade Adresse des Toggle Output Registers
    str r3, [r2]					// Schalte alle LEDs zu Beginn des Betriebes aus

    str r1, [r2]					// Neue Ausgabe fuer die LED Anzeige

    bx lr                         	// Rueckkehr aus dem Unterprogramm

/*
 * Unterprogramm fuer den schwarzen Schalter (SW1), das gegebenenfalls das
 * mod Flag entsprechend setzt. Zunaechst wird 5ms gewartet und dann geprueft,
 * ob der Taster noch gedrueckt ist. Ist dies der Fall, so wird mod gesetzt und 
 * ist dies nicht der Fall so wird einfach zurueck gesprungen.
 *
 * Parameter: keine
 * Rueckgabe: keine
*/
.thumb_func
check_button_sw1:
    ldr r0, =GPIOA_PDIR_SW1			// Ueberpruefen, ob der Taster 
    ldr r1, [r0]					// nach 5ms immer noch gedrueckt ist
    cmp r1, #0						// ist das nicht der Fall
    bne end_check_button_sw1		// kehre aus UP zurueck und setze mod nicht

    ldr r0, =mod					// Ist der Taster immer noch gedrueckt, dann 						
    ldr r1, [r0]					// setze das entsprechende Bit der mod  
    orr r1, r1, #1					// Variablen auf 1
    str r1, [r0]
  
end_check_button_sw1:
    bx lr							// Rueckkehr aus dem Unterprogramm

/*
 * PIT-ISR (Interrupt Service Routine) durch die eine Verzoegerung von 1 Sekunde realisiert
 * wird, was fuer das Zaehlen in diesem Programm benoetigt wird.
 *
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

/*
 * PIT2-ISR (Interrupt Service Routine) durch die das mod Flag gesetzt werden kann, wenn der
 * Taster SW2 gedrueckt wurde. Wird SW2 gedrueckt so wird im Hauptprogramm der PIT2 gestartet.
 * In der Initialisierung wurde der PIT2 mit einem Startwert von 5ms belegt, also wird diese ISR
 * 5ms nach einem Tastendruck auf SW2 ausgeloest. In der ISR wird der Taster SW2 dann erneut
 * abgefragt und ist dieser immer noch gedrueckt, dann wird das mod Flag entsprechend gesetzt.
 *
 * Parameter: keine Parameter moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 * Rueckgabe: keine Rueckgabe moeglich, da die ISR asynchron zum Programmablauf aufgerufen wird	
 */
.thumb_func
isr_pit2:
    ldr r0, =PIT_TFLG2              // TIF (Timer Interrupt Flag) loeschen
    ldr r1, =0x1
    str r1, [r0]         

    ldr r0, =GPIOE_PDIR_SW2         // Lade die Adresse des GPIO-Pins in R0
    ldr r1, [r0]                    // Lade den Zustand des GPIO-Pins in R1
    cmp r1, #0						// Ist der Taster nicht mehr gedrueckt,
    bne skip						// ueberspringe (ungueltiger Tastendruck)
    
    ldr r0, =mod					// Ist der Taster aber immer noch gedrueckt,
    ldr r1, [r0]
    orr r1, r1, #2					// Setze das entsprechende Bit in mod (Bit 1)
    str r1, [r0]
   
skip:
    ldr r0, =PIT_TCTRL2_TEN			// In jedem Fall wird der PIT2 
    mov r1, #0						// wieder ausgeschaltet und ist so
    strb r1, [r0]					// wieder bereit fuer den naechsten Tastendruck

    bx lr

/*** Datenbereich (ab 0x20000000) ***/
.data
counter: .word 0					// Variable fuer den Zaehler
pit1_flag: .word 0					// PIT1 Benutzer Flag, um Zaehler hochzuschalten
mod: .word 0						// Bit 0: nichts, Bit 1: SW1 gueltig, Bit 2: SW2 gueltig, Bit 3: SW1 gedrueckt, Bit 4: SW2 gedrueckt
direction: .word 1          		// 1: Aufwaertszaehlen, 0: Abwaertszaehlen
running: .word 1					// 1: Zaehler laeuft, 0: Zaehler ist angehalten
str_start: .asciz "Zaehler gestartet.\n"
str_stopp: .asciz "Zaehler angehalten.\n"
str_up: .asciz "Richtung geaendert. Es wird jetzt hoch gezaehlt.\n"
str_down: .asciz "Richtung geaendert. Es wird jetzt runter gezaehlt.\n"
str_dir_switched: .asciz "Richtung geaendert!\n"
