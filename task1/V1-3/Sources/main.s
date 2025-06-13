/************************************************************
Versuch: 1-3
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 10 Stunden
************************************************************/

/*
Antwort zu Aufgabenteil 1-3(d):
Bei Messung der Takte und nach Abzug des PIT3-Overheads haben wir folgende Ergebnisse
erhalten:

	1) Ohne DSP-Befehle: 68 Takte
	2) Mit DSP-Befehlen: 7 Takte
	
Also hat sich gezeigt, dass die Nutzung der DSP Befehle und der Flags des APSR die Anzahl
der benötigten Takte deutlich reduzieren kann. In diesem Beispiel war ungefaehr eine 
Verbesserung um den Faktor 10 moeglich, was ein sehr grosser Unterschied ist. Abgesehen 
davon ist auch der tatsaechliche Code deutlich kuerzer, was zusaetzlich noch Einfluss auf 
die Lesbarkeit hat.   
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
.EQU COUNTER, 0x8				// Zaehler fuer Anzahl der Durchlaeufe
.EQU PIT3_OVERHEAD, 0xb			// Overhead fuer PIT3

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init
	bl pit3_init

start:
	mov r4, #COUNTER			// Zaehler laden
	ldr r0, =str_eingabe		
	bl uart_putString			
	
	// Aufruf des Unterprogrammes fuer die Eingabe
	bl eingabe

	// Vektor 1 auf das Terminal ausgeben
	ldr r0, =str_prompt_v1		
	bl uart_putString			
	ldr r5, =vektoren_array		
	ldr r0, [r5]
	bl uart_putInt32
	
	// Vektor 2 auf das Terminal ausgeben
	ldr r0, =str_prompt_v2		
	bl uart_putString			
	ldr r5, =vektoren_array		
	add r5, r5, #4				// Addiere Offset fuer Vektor 2
	ldr r0, [r5]
	bl uart_putInt32
	
	// Initialisierungen fuer die Berechnungen
	ldr r0, =str_ohne
	bl uart_putString
	mov r4, #0x4				// Setze Zaehler wieder auf 4
	ldr r5, =vektoren_array		// Startadresse des 1. Vektors
	ldr r6, =vektoren_array		// Startadresse des 2. Vektors
	add r6, r6, #0x4			// (hier wurde das Offset addiert)

/*
Beginn der Berechnung von einem Minimums- und Maximumsvektor nach Vorgaben der
Aufgabenstellung. Hierbei werden kein DSP-Befehle genutzt.
*/
	
	// Zeitmessung Start
	bl pit3_getval 				// Zeitmessung 1. Wert
	mov r11, r0					// Zwischenspeichern des Zeitwertes
	
	// Initialisieren der Ergebnisregister r9 und r10
	mov r9, 0x0					// fuer den Fall, dass sie beschrieben sind
	mov r10, 0x0				// (vor allem bei wiederholter Ausfuehrung)

loop_max_min:
	ldrb r7, [r5], #1			// lade in r7 was an r5 steht und erhoehe Adresse
	ldrb r8, [r6], #1			// lade in r7 was an r6 steht und erhoehe Adresse
	cmp r7, r8					// verleiche Werte in r7 und r8
	
	// Setze Werte den Flags entsprechend
	it ge						
	addge r10, r7
	it ge
	addge r9, r8
	it lo
	addlo r10, r8
	it lo
	addlo r9, r7
	
	// Rotiere Ergebnisregister, so dass das naechste Byte an die richtige Stelle kommt
	ror r9, #0x8
	ror r10, #0x8
	
	// Dekrementiere Zaehler und springe zum Anfang des Loopes
	subs r4, r4, #1
	bne loop_max_min
	
	// Zeitmessung Ende und Ausgabe der Anzahl an Takten
	bl pit3_getval				// Zeitmessung 2. Wert
	sub r11, r11, r0			// Takte ausrechnen
	sub r0, r11, #PIT3_OVERHEAD // pit3_getval Overhead abziehen
	bl uart_putByteBase10		// Dauer ausgeben in dezimaler Form
	
	// Ausgabe des Minimums auf das Terminal
	ldr r0, =str_prompt_min
	bl uart_putString
	mov r0, r9
	bl uart_putInt32
	
	// Ausgabe des Maximums auf das Terminal
	ldr r0, =str_prompt_max
	bl uart_putString
	mov r0, r10
	bl uart_putInt32
	
/*
Beginn der Berechnung von einem Minimums- und Maximumsvektor nach Vorgaben der
Aufgabenstellung. Hierbei werden dieses Mal DSP-Befehle genutzt.
*/
	
	// Zeitmessung Start
	bl pit3_getval 				// Zeitmessung 1. Wert
	mov r11, r0					// Zwischenspeichern des Zeitwertes
	
	ldr r7, [r5, #-4]			// lade in r7 was an r5 steht (Offset wegen Erhöhung vorher)
	ldr r8, [r6, #-4]			// lade in r7 was an r6 steht (Offset wegen Erhöhung vorher)
	usub8 r9, r8, r7			// DSP Operation, die GE[3:0] des APSR entsprechend setzt
	sel r9, r7, r8				// waehle Bytes den vorher gesetzten Flags des 
	sel r10, r8, r7				// APSR entsprechend aus und speichere in Ergebnisregister

	// Zeitmessung Ende
	bl pit3_getval				// Zeitmessung 2. Wert
	sub r11, r11, r0			// Takte ausrechnen

	// Ausgabe des Prompts "mit DSP Befehlen"
	ldr r0, =str_mit
	bl uart_putString
	
	// Ausgabe der Anzahl an Takten
	sub r0, r11, #PIT3_OVERHEAD // pit3_getval Overhead abziehen
	bl uart_putByteBase10		// Dauer ausgeben in dezimaler Form
	
	// Ausgabe des Minimums auf das Terminal
	ldr r0, =str_prompt_min
	bl uart_putString
	mov r0, r9
	bl uart_putInt32
	
	// Ausgabe des Maximums auf das Terminal
	ldr r0, =str_prompt_max
	bl uart_putString
	mov r0, r10
	
	// Ausgabe von zwei Leerzeilen zur Lesbarkeit
	bl uart_putInt32
	ldr r0, =str_nl
	bl uart_putString
	ldr r0, =str_nl
	bl uart_putString
	
	// Springe zum Anfang, wiederhole das Programm
	b start

/*
Hier beginnt das Unterprogramm fuer die Eingabe der beiden Vektoren.
*/

// Assemblerdirektiven
.thumb_func

eingabe:	
	ldr r5, =vektoren_array		// Adresse des Arrays laden
	push {lr}					// Schiebe Adresse im lr auf den Stack
		
loop_eingabe:
	bl uart_getByte				// ein Byte einlesen
	strb r0, [r5], #1			// im Array ablegen und Adresse in r5 erhoehen
	subs r4, r4, #1				// Zaehler dekrementieren
	bne loop_eingabe			// solange der Zaehler noch nicht Null ist, springe zurueck

	pop {lr}					// Hole Adresse des lr vom Stack
	bx lr						// Springe zur Adresse im lr

/*** Datenbereich (ab 0x20000000) ***/
.data
vektoren_array: .space COUNTER
str_eingabe: .asciz "Bitte 8 Byte fuer 2 Vektoren eingeben! Je 4 Byte fuer einen Vektor.\n"
str_prompt_v1: .asciz "\n v1: 0x"
str_prompt_v2: .asciz "\n v2: 0x"
str_ohne: .asciz "\n\nOhne DSP-Befehle (Dauer: "
str_mit: .asciz "\n\nMit DSP-Befehlen (Dauer: "
str_prompt_min: .asciz " Takte):\n\n min: 0x"
str_prompt_max: .asciz "\n max: 0x"
str_nl: .asciz "\n"
