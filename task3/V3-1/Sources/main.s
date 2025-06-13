/************************************************************
Versuch: 3-1
Name: Philip Redecker
Matrikel-Nr.: 3257525
Zeitbedarf: 9 Stunden
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

// Konstanten
.EQU NEW_LINE, 0x0a					// Konstante fuer eine neue Zeile (Ascii-Code)
.EQU SPACE, 0x20				  	// Konstante fuer das Leerzeichen (Ascii-Code)
.EQU CRC_POLYNOMIAL, 0x04c11db7 	// Konstante fuer das verwendete CRC Polynom
.EQU CRC_GPOLY, 0x40032004			// Konstante fuer die Adresse des Registers in das das Polynom geschrieben werden muss
.EQU CRC_SEED, 0x12345678		 	// Konstante fuer den verwendeten CRC Seed
.EQU CRC_CRC, 0x40032000			// Konstante fuer die Adresse des CRC Registers (Schreibe Seed, Daten, erhalten Ergebnisse)
.EQU CRC_CTRL, 0x40032008			// Konstante fuer die Adresse der CRC Kontrollregisters
.EQU INIT_CRC_CTRL, 0x01000000		// Konstante fuer die Intialwerte des CRC Kontrollregisters (TOT, TOTR und FXOR sollen auf 00 bzw. 0 nach Vorgabe)

// Konstanten fuer das Einschalten von CRC im SIM
__BBREG SIM_SCGC6_CRC, 0x4004803C, 18					// Berechnung der BBA des Bit 18 der Basisadresse des SCGC6 Registers des SIM 

// Konstanten fuer die Bearbeitung des Kontrollregisters des CRC
__BBREG CRC_CTRL_WAS, 0x40032008, 25					// Berechnung der BBA des Bit 25 der Basisadresse des CRC Kontrollregisters

/*
* Hauptprogramm (main): Wird nicht direkt nach dem Reset, sondern von einer Routine aufgerufen, 
* die nach einem Reset die grundlegende Systeminitialisierung durchfuehrt. Man darf also nicht davon ausgehen,
* dass die Register mit ihrem Reset-Wert vorbelegt sind.
*/
main:	
	bl uart_init
	
/*
Initialisieren des CRC nach Vorgaben. Hierbei wurde sich an den Vorgaben im Handbuch auf Seite 785
(Kapitel ueber CRC) orientiert. Es wurde das gesamte Kontrollregister beschrieben, obwohl einige
Werte (zum Beispiel die Bits fuer TOT und TOTR) die gewuenschten Werte hatten. Der Grund dafuer ist,
dass nicht davon ausgegangen werden sollte, dass die Register mit ihrem Reset-Wert vorbelegt sind
und deshalb wurden hier trotzdem die entsprechenden Werte mittels einer Konstante INIT_CRC_CTRL
geschrieben.	
*/

    ldr r0, =SIM_SCGC6_CRC	      	// Lade Adresse eines Registers des SIM, um das CRC Modul zu aktivieren
    mov r1, #1					  	// Lade Aktivierungsbit
    strb r1, [r0]				  	// Aktiviere das CRC Modul im SIM

    ldr r0, =CRC_CTRL			  	// Lade die Adresse des CRC Kontrollregisters und lade dann den
    mov r1, #INIT_CRC_CTRL		  	// Initialwert fuer dieses Register. Dieser ist so gewaehlt, dass die TOT und TOTR Bits auf 00 
    str r1, [r0]				  	// stehen und das FXOR Bit auf 0 steht. Einzig das TCRC Bit wird gesetzt (fuer den 32 Bit Betrieb).
    
    ldr r0, =CRC_GPOLY			  	// Lade Adresse an die das Polynom geschrieben werden soll
    ldr r1, =CRC_POLYNOMIAL		  	// Lade das Polynom 
    str r1, [r0]				  	// Schreibe das Polynom an die Adresse
    
    ldr r0, =CRC_CTRL_WAS		  	// Lade Adresse des WAS-Bit im CRC Kontrollregister, um
	mov r1, #1					  	// dann hier dieses Bit zu setzen, denn so kann ein Seed
    strb r1, [r0]				  	// Wert geschrieben werden
    
    ldr r4, =CRC_CRC			  	// Lade Adresse des CRC Daten-, Seed- und Ergebnisregisters (in r4, da wir sie immer wieder brauchen werden)
    ldr r1, =CRC_SEED			  	// Lade den vorgegebenen Seed
    str r1, [r4] 				  	// und schreibe diesen in das Register
    
    ldr r0, =CRC_CTRL_WAS		  	// Lade Adresse des WAS-Bit im CRC Kontrollregister, um
	mov r1, #0					  	// dann hier dieses Bit zu clearen, denn so koennen im Folgenden
    strb r1, [r0]				  	// Daten zur Berechnung in das CRC_CRC Register geladen werden. 
    
/*
Hier wird mit der Berechnung der CRC Pruefsumme begonnen. Es wird zunaechst der test_str geladen und 
dann wird dieser Wort fuer Wort durchgegangen bis in einem Wort der Nullterminator auftritt. Entweder
endet der String genau auf einem Wortende (es wird zu print gesprungen, siehe Zeilen 89-90) oder die 
hintersten Byte des Strings werden mit den Nullen, die wegen der .align Direktive eingefuellt wurden, 
eingelesen und danach wird zu print uebergegangen (siehe Zeilen 94-96).
*/
    
	ldr r0, =test_str			  	// Lade Adresse des Test Strings

loop_uebergabe_string:
	ldr r1, [r0], #4    	      	// Lade was an aktueller Adresse steht und inkrementiere Adresse danach
	
	cmp r1, #0					  	// Besteht der String nur aus Nullen, springe weiter. Dies ist fuer den Fall, dass der Eingabestring 
	beq print					  	// genau beim Ende eines 32 Bit Wortes auskommt (0000_0000 am Ende kann uebersprungen werden)
	
	str r1, [r4]				  	// Schreibe den atkuell betrachtetet Teil der Eingabe in das CRC Eingaberegister (zur Berechnung)

	lsr r2, r1, #24				  	// Kontrolliere das Most Significant Byte des aktuellen Wertes.         
	cmp r2, #0					  	// Ist das Most Significant Byte des aktuellen Wortes nicht 0x00,
	bne loop_uebergabe_string	  	// dann springe zurueck, sonst drucke das Ergebnis

/*
Hier wird nun das Ergebnis ausgegeben. Es werden vorbereitete Strings aus dem Speicher geladen
und es wird das Ergebnis aus dem CRC_CRC Register gelesen und ausgegeben.
*/
		
print:
	ldr r0, =result_str				// String Adresse laden
	bl uart_putString				// String ausgeben
	
	ldr r0, =test_str				// String Adresse laden
	bl uart_putString				// String ausgeben
	
	ldr r0, =result_sum_str			// String Adresse laden
	bl uart_putString				// String ausgeben
	
	ldr r0, [r4]					// Lese Inhalt des CRC_CRC Registers
	bl uart_putInt32				// Gebe den Inhalt (das Ergebnis) aus
	
	mov r0, #NEW_LINE				// Fuege zwei Zeilenumbrueche ein,
	bl uart_putChar					// fuer den Fall, dass mehrere Berechungen 
	mov r0, #NEW_LINE				// nacheinander durchgefuehrt werden sollen
	bl uart_putChar
	
end:
	b end

/*** Datenbereich (ab 0x20000000) ***/
.data
test_str: .asciz "Praktikum und Werkstatt Technische Informatik, FernUniversitaet Hagen"
/*
Hier wird die .align Direktive genutzt, um den Speicher so auszurichten, dass alle Zeichen des 
Strings beachtet und gleichzeitig keine Zeichen/Eintraege des nachfolgenden Speichers mit
einbezogen werden. So kann sichergestellt werden, dass bei einem wortweisen Zugriff auf die
obere Variable nicht aus Versehen auf die naechste Variable zugegriffen wird.
*/
.align 4
result_str: .asciz "Es wurde der String\n\n'"
result_sum_str: .asciz "'\n\nuebergeben und die berechnete CRC-Pruefsumme ist: "
