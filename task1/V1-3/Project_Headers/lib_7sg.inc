/*
 * lib7sg2.inc
 */

#define RAW 0
#define HEX 1

/*
*** Segment Zuordnungen (wie ueblich) ***
    a
  -----
 |     |
f|     |b
 |  g  |
  -----
 |     |
e|     |c
 |     |
  -----  o (DP) 
    d
    
* Bit-Segment Zuordnungen (NICHT wie ueblich!)	*
* Bit-Nr.:  7 6 5 4 3 2 1 0						*
* Segment: DP a b c e g f d						*

Das ICM7218 invertiert die Darstellung des Dezimalpunkts (DP)!
Die implementierten Funktionen korrigieren das und stellen bei Bit#7=1 (0x80) den Dezimalpunkt dar.
Die Funktionen beruecksichtigen und aendern auch die unueblichen Bit-Segment Zuordnungen (s.o.) des ICM7218, 
so dass die folgende Zuordnung gilt:

*** Bit-Segment Zuordnungen (anwenderfreundlich) ***   
Bit-Nr.:  7 6 5 4 3 2 1 0
Segment: DP g f e d c b a

*** Funktionen ***
Uebergabeparameter: R0..R2 in der Reihenfolge beim Aufruf
Rueckgabewert: R0

Alle Funktionen arbeiten mit einem Puffer im RAM des K60.
*/

// 7-Segment-Anzeige initialisieren (Modul-Clock, Ports)
// keine Parameter
.extern init7sg

// 7-Segment-Anzeige testen
// keine Parameter
.extern demo7sg

//  7-Segment-Anzeige loeschen
// keine Parameter
.extern clr7sg

// zeigt einen 32-bit-Wert in der 7-Segment-Anzeige an
// Parameter: Wert in R0
.extern showhex7sg

// zeigt ein 64-bit-Muster (8 x 8 Bit) in der 7-Segment-Anzeige an
// das Muster wird entsprechend der Bit-Segment Zuordnung (s.o.) angezeigt
// Parameter: 32 bit (H) in R0, 32 bit (L) in R1
.extern showraw7sg

// schreibt einen 8-bit-Wert (data) an die Stelle (pos [0..7]) in den Anzeigepuffer
// hier erfolgt noch keine Ausgabe auf der 7-Segment-Anzeige (Aufruf von showdata7sg)
// code=0 => keine Umcodierung
// code=1 => das untere Nibble wird umcodiert, so dass "0..F" dargestellt werden kann
// Parameter: data in R0, pos in R1, code in R2
.extern putx7sg

// es wird der Wert (Muster) der Stelle (pos [0..7]) zurueckgegeben (aus dem Anzeigepuffer)
// Parameter: pos in R0
// Rueckgabe: Muster (s.o.) in R0
.extern getx7sg

// Darstellung des Anzeigepuffers (mit putx7sg gesetzt) in der 7-Segment-Anzeige
// keine Parameter
.extern showdata7sg

