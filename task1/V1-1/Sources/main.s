/************************************************************
Versuch: 1-1
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: Studientag
************************************************************/

/*
Antwort zum Aufgabenteil e):
Es wurden nun 3 verschiedene Szenarien getestet:

  1) Platziere das Maximum am Anfang der Liste
  2) Platziere das Maximum am Ende der Liste
  3) Trage die Elemente in die Liste so ein, dass jedes Element ein neues Maximum ist
  
Dies wurde so getestet, um zu untersuchen, ob die Position des Maximums 
oder die Anzahl der Schreibbefehle im loop_maximum einen Einfluss auf die 
Laufzeit des Programmes haben. In allen Fällen wurde eine Dauer von 126 
Takten gemessen, das heißt die angesprochenen Faktoren haben keinen Einfluss
auf die Suchzeit. Wenn im Debug Modus Zeile fuer Zeile durch die Ausfuehrung
gegangen wird, faellt auf, dass hier der Befehl (movhi) trotzdem geladen
wird. Nur wird dieser dann nicht ausgefuehrt, da das entsprechende Flag nicht
gesetzt ist. Jedoch wird durch das Laden des Befehls schon genug Platz fuer
die Ausfuehrung des Befehls eingeplant (Pipelining) und dies fliesst entsprechend
in die Zeitmessung mit ein, egal ob der Befehl auch ausgefuehrt wird oder nicht.
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
.EQU COUNTER, 0x10				// Zaehler fuer Anzahl der Durchlaeufe
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
	ldr r5, =bytearray			// Adresse des Arrays laden
	ldr r0, =str_eingabe		// String-Adresse laden
	bl uart_putString			// String ausgeben
	
loop_eingabe:
	ldr r0, =str_prompt			// String Adresse laden
	bl uart_putString			// String ausgeben
	bl uart_getByte				// ein Byte einlesen
	strb r0, [r5], #1			// im Array ablegen und Adresse in r5 erhoehen
	bl uart_putByte				// Byte ausgeben
	subs r4, r4, #1				// Zaehler dekrementieren
	bne loop_eingabe			// solange der Zaehler noch nicht Null ist, springe zurueck
	
	// Maximumsbestimmung
	ldr r0, =str_startsuche		// String-Adresse laden
	bl uart_putString			// String ausgeben
	mov r4, #COUNTER			// Zaehler initialisieren
	mov r9, #0					// temp. Maximum initialisieren
	
	// Zeitmessung
	bl pit3_getval 				// Zeitmessung 1. Wert
	mov r11, r0					// Zwischenspeichern des Zeitwertes
	
loop_maximum:
	ldrb r0, [r5, #-1]! 		// Byte aus dem Array holen, vorher die Adresse in r5 dekrementieren
	cmp r0, r9					// mit bisherigem Maximum vergleichen
	it hi						// wenn es groesser ist (unsigned)
	movhi r9, r0				// wird das bisherige Maximum ersetzt
	subs r4, r4, #1				// Zaehler dekrementieren
	bne loop_maximum			// Solange der Zaehler noch nicht Null ist, springe zurueck
	
	// Zeitmessung
	bl pit3_getval				// Zeitmessung 2. Wert
	sub r11, r11, r0			// Takte ausrechnen
	
	ldr r0, =str_endesuche		// String Adresse laden
	bl uart_putString			// String ausgeben
	
	ldr r0, =maximum			// Adresse laden von maximum
	strb r9, [r0]				// Maximum im Speicher ablegen
	
	mov r0, r9					// Maximum nach r0 laden
	bl uart_putByte				// Maximum ausgeben
	
	ldr r0, =str_dauer			// String-Adresse laden
	bl uart_putString			// String ausgeben
	sub r0, r11, #PIT3_OVERHEAD // pit3_getval Overhead abziehen
	bl uart_putInt16			// Dauer ausgeben als 4-stellige Hex-Zahl
	ldr r0, =str_takte			// String Adresse laden
	bl uart_putString			// String ausgeben
	
	b start 

/*** Datenbereich (ab 0x20000000) ***/
.data
bytearray: .space COUNTER
maximum: .byte 0x00
str_eingabe: .asciz "Bitte 16 Byte sukzessiv eingeben!\n"
str_prompt: .asciz "\n> 0x"
str_startsuche: .asciz "\nDurchsuchen gestartet.\n"
str_endesuche: .asciz "Durchsuchen beendet.\nMaximum: 0x"
str_dauer: .asciz "\nDauer: "
str_takte: .asciz " Takte\n"
