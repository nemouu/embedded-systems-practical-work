// Makro fuer Bit-Band-Alias-Adressen
// Aufruf: __BBREG (Makro) NAME: Name der Konstanten, ADDRESS: Adresse des Registers (0x40xxxxxx), BIT: Bitnummer (0..31)
// Der Name der Konstanten sollte so gewaehlt werde, dass er in sinnvoller Weise die Funktion bzw. Register und Bit darstellt. 
// D. h. man sollte nicht gezwungen sein, im Handbuch nachschlagen zu muessen.   
.macro __BBREG NAME, ADDRESS, BIT
.equ \NAME, (\ADDRESS - 0x40000000) << 5 + 0x42000000 + \BIT << 2
.endm
