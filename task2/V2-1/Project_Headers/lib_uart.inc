/*
 * lib_uart.inc
 */
#ifndef LIB_UART_H_
#define LIB_UART_H_

// Initialisiert das Terminal (UART5) mit 19200 Baud, 8 Datenbits, keine Paritaet und 1 Stoppbit. 
// Keine Parameter
.extern uart_init

// Prueft, ob ein Zeichen angekommen ist. Gibt Null in R0 zurueck, falls kein Zeichen empfangen wurde.
// R0 ist ungleich Null, wenn ein Zeichen empfangen wurde; das Zeichen selbst wird nicht geladen.
.extern uart_charPresent

// Wartet, bis ein Zeichen vom Terminal empfangen wurde und gibt es in R0 zurueck.
.extern uart_getChar

// Liest einen zweistelligen hexadezimalen Wert vom Terminal ein und gibt ihn in R0 zurueck.
.extern uart_getByte

// Liest einen zweistelligen dezimalen Wert (00-99) vom Terminal ein und gibt ihn in R0 zurueck.
.extern uart_getByteBase10

// Gibt ein ASCII-Zeichen auf dem Terminal aus. Uebergabe in R0.
.extern uart_putChar

// Gibt einen nullterminierten String auf dem Terminal aus. Uebergabe der Anfangsadresse in R0.
.extern uart_putString

// Gibt ein Byte in hexdezimaler Form auf dem Terminal aus. Uebergabe in R0.
.extern uart_putByte

// Gibt ein Byte in dezimaler Form auf dem Terminal aus. Uebergabe in R0.
.extern uart_putByteBase10

// Gibt ein Wort (16 Bit) in hexadezimaler Form auf dem Terminal aus. Uebergabe in R0.
.extern uart_putInt16

// Gibt ein Wort (32 Bit) in hexadezimal Form auf dem Terminal aus. Uebergabe in R0.
.extern uart_putInt32

#endif /* LIB_UART_H_ */
