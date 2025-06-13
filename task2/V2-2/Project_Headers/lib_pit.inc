/*
 * lib_pit.inc
 */

// Initialisiert den PIT3 wie folgt:
// PIT_MCR=0x0  Timer Clock enabled, Timers running in debug mode
// PIT_LDVAL3=0xFFFFFFFF PIT1 Start Value
// PIT_TCTRL3=0x3 Timer PIT1 aktiv, Interrupt disabled
.extern pit3_init

// Liest den aktuellen Zaehlerwert von PIT3 aus und gibt ihn in R0 zurueck
.extern pit3_getval

