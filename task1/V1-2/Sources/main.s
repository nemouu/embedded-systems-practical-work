/************************************************************
Versuch: 1-2
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 8 Stunden
************************************************************/

/*
Antworten zu den Vorbereitungsfragen:

(1)
Es gibt eine Bit Band Region fuer den oberen Teil des SRAM und der Bit
Band Alias Bereich beginnt bei 0x22000000. Ausserdem gibt es noch eine
Bit Band Region fuer die Steuerregister und der entsprechende Bit Band
Alies Bereich beginnt bei 0x42000000.

(2)
Die gegebene Adresse 0x20000000 liegt in der Bit Band Region des SRAM und
deshalb nutzen wir in der folgenden Berechnung die entsprechenden 
Adressen fuer die Bit Band Alias Region des SRAM. Da nicht nach der Adresse
eines einzelnen Bits gesucht wird, sondern nach dem Bereich gefragt wird,
berechnen wir die Bit Band Alias Adresse (BBAA) einmal mit Bitnummer 0 und
dann nochmal mit Bitnummer 31. Zur Berechnung nutzen wir ausserdem die 
bekannte Formel (siehe Folien vom Studientag). Wir erhalten so

	BBAA_0 = 0x22000000 + (0x20000000 - 0x20000000) x 32 + 0 x 4
		   = 0x22000000 (-> Adresse des ersten Bits)
		   
	BBAA_31 = 0x22000000 + (0x20000000 - 0x20000000) x 32 + 31 x 4
		    = 0x22000000 + 0x7c
		    = 0x2200007c (-> Adresse des letzten Bits)
		   
Der BBA-Adressbereich zwischen 0x22000000 und 0x2200007c gehoert also zur
Adresse 0x20000000.

(3)
Die gegebene Adresse 0x40041000 liegt in der Bit Band Region der Steuerregister,
das heisst in diesem Fall nutzen wir die entsprechenden Adressen fuer die 
Bit Band Alias Region der Steuerregister. Das Verfahren ist ansonsten genau
wie in Aufgabenteil (2). Wir erhalten hier

	BBAA_0 = 0x42000000 + (0x40041000 - 0x40000000) x 32 + 0 x 4
		   = 0x42000000 + 0x00041000 x 32
		   = 0x42000000 + 0x00820000
		   = 0x42820000 (-> Adresse des ersten Bits)
		   
	BBAA_31 = 0x42000000 + (0x40041000 - 0x40000000) x 32 + 31 x 4
		    = 0x42820000 + 0x7c
		    = 0x4282007c (-> Adresse des letzten Bits)
		   
Der BBA-Adressbereich zwischen 0x42820000 und 0x4282007c gehoert also zur
Adresse 0x40041000.
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
.EQU RFSYS_REG0, 0x40041000		// Adresse fuer das erste Register als Konstante
.EQU RFSYS_REG4, 0x40041010		// Adresse fuer das zweite Register als Konstante
.EQU INIT_VALUE, 0x0000ffff				// Initialwert fuer die oben genannten Register

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init
	
	/*
	Initialisieren der Werte an den beiden Adressen der genutzten Register. 
	Es wird dieser Wert genutzt, da es so moeglich ist die Veraenderungen 
	durch das setzen bzw. zuruecksetzen bestimmter Bits direkt nachzuvollziehen.
	*/
	
start:
	ldr r0, =INIT_VALUE
	ldr r1, =RFSYS_REG0
	str r0, [r1]
	ldr r1, =RFSYS_REG4
	str r0, [r1]
	
	// Prompt fuer die Eingabe der Bytes
	ldr r0, =str_eingabe
	bl uart_putString
	
	// Initialisieren einer Maske, die hilft zu grosse Bytes abzuschneiden
	mov r4, #0x1f
	
	// Byte Nummer 1 (1-Bit) - Zwischenspeichern in r5
	ldr r0, =str_eins_bit
	bl uart_putString
	bl uart_getByte
	and r0, r0, r4
	mov r5, r0
	bl uart_putByte
	
	// Byte Nummer 2 (0-Bit) - Zwischenspeichern in r6
	ldr r0, =str_null_bit
	bl uart_putString
	bl uart_getByte
	and r0, r0, r4
	mov r6, r0
	bl uart_putByte
	
	/*
	Hier startet die Bit-Manipulation ohne Bit Banding. Die Ausgabe auf das
	Terminal startet hierbei nach der Berechnung der Werte. Bei der Ausgabe
	wird nicht direkt auf die Werte des Registers zugegriffen, da wir diese
	direkt berechnet hatten und sie danach erst in die Register geschrieben
	haben.
	*/
	
	// Setzen des 1-Bits ohne Bit Banding
	mov r4, #0x1
	lsl r7, r4, r5
	ldr r0, =RFSYS_REG0
	ldr r1, [r0]
	orr r8, r1, r7
	mov r9, r8 					// Ablegen des Ergebnisses fuer Ausgabe
	str r8, [r0]				// Speichern des Ergebnisses in RFSYS_REG0
	
	// Zuruecksetzen des 0-Bits ohne Bit Banding
	lsl r7, r4, r6
	mvn r7, r7
	and r8, r8, r7
	str r8, [r0] 				// Speichern des Ergebnisses in RFSYS_REG0
	
	// Ausgabe auf dem Terminal
	ldr r0, =str_ohne
	bl uart_putString
	ldr r0, =INIT_VALUE
	bl uart_putInt32
	ldr r0, =str_pfeil
	bl uart_putString
	mov r0, r9
	bl uart_putInt32
	ldr r0, =str_pfeil
	bl uart_putString
	mov r0, r8
	bl uart_putInt32
	ldr r0, =str_nl
	bl uart_putString
	
	/* 
	Hier startet die Bit-Manipulation mit Bit Banding. Die Ausgabe auf das 
	Terminal erfolgt hier Schritt fuer Schritt. Dazu wird immer der Wert 
	der Adresse geladen, da wir diesen Wert beim Bit Banding nicht "direkt" 
	beeinflussen.
	*/
	
	//Berechnung der BBAA (zunaechst ohne die Bitnummer mit ein zu beziehen)
	ldr r0, =RFSYS_REG4
	sub r4, r0, #0x40000000		// (BBAdresse - BBBasisadresse) 
	lsl r4, r4, #5				// Multiplikation mit 2^5 = 32
	add r4, r4, #0x42000000		// Addieren der BBA-Basisadresse
	mov r7, #0x4				// Ein Register mit 4 fuer BitNr-Berechnung
	
	// Ausgabe auf das Terminal (Text und Initialwert)
	ldr r0, =str_mit
	bl uart_putString
	ldr r0, =INIT_VALUE
	bl uart_putInt32
	ldr r0, =str_pfeil
	bl uart_putString
		
	// Setzen des 1-Bits mit Bit Banding
	mul r8, r5, r7				// 4 * Bitnummer
	add r8, r4, r8				// Verbleibende Berechnung, Ergebnis ist die BBAAdresse
	mov r9, #0x1
	str r9, [r8]
	
	// Ausgabe nach Setzen des 1-Bits
	ldr r1, =RFSYS_REG4
	ldr r0, [r1]
	bl uart_putInt32
	ldr r0, =str_pfeil
	bl uart_putString
		
	// Zuruecksetzen des 0-Bits mit Bit Banding
	mul r8, r6, r7				// 4 * Bitnummer
	add r8, r4, r8				// Verbleibende Berechnung, Ergebnis ist die BBAAdresse
	mov r9, #0x0
	str r9, [r8]
	
	// Ausgabe nach Zuruecksetzen des 0-Bits
	ldr r1, =RFSYS_REG4
	ldr r0, [r1]
	bl uart_putInt32
	ldr r0, =str_nl
	bl uart_putString
	ldr r0, =str_nl
	bl uart_putString
	
	b start

/*** Datenbereich (ab 0x20000000) ***/
.data
str_eingabe: .asciz "Bitte je 2 Byte fuer das 0-Bit und das 1-Bit eingeben!\n\n"
str_null_bit: .asciz "\nNummer des 0-Bits: "
str_eins_bit: .asciz "Nummer des 1-Bits: "
str_ohne: .asciz "\n\nBei der Bitmanipulation ohne Bit Banding erhalten\nwir (Initial -> Setzen -> Zuruecksetzen):\n\n    "
str_mit: .asciz "\nBei der Bitmanipulation mit Bit Banding erhalten\nwir (Initial -> Setzen -> Zuruecksetzen):\n\n    "
str_pfeil: .asciz " -> "
str_nl: .asciz "\n"
