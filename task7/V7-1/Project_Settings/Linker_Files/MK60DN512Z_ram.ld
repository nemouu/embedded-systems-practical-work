/*
*****************************************************************************
**
**  File        : K60DN512Z_ram.ld
**
** 	Default linker command file for RAM targets
**
*****************************************************************************
*/
/* Entry Point */
ENTRY(__thumb_startup)

/* Specify the memory areas */
MEMORY
{
  m_text        (rx) : ORIGIN = 0x1FFF0000, LENGTH = 0x00008000	/* 32k */
  m_lib_text    (rx) : ORIGIN = 0x1FFF8000, LENGTH = 0x00007E00 /* 32k - 512B*/
  m_interrupts	(rx) : ORIGIN = 0x1FFFFE00, LENGTH = 0x00000200
  m_data		(rw) : ORIGIN = 0x20000000, LENGTH = 0x00006000	/* 24k */	
  m_lib_data	(rw) : ORIGIN = 0x20006000, LENGTH = 0x00006000 /* 24k */
  m_stack       (rw) : ORIGIN = 0x2000C000, LENGTH = 0x00002000	/* 8k */
  m_heap        (rw) : ORIGIN = 0x2000E000, LENGTH = 0x00002000	/* 8k */
}

_estack = ORIGIN(m_heap);
__SP_INIT = _estack;
__heap_addr = ORIGIN(m_heap);
__heap_size = LENGTH(m_heap); 
__stack_size = LENGTH(m_stack);

/* Define output sections */
SECTIONS
{
  .interrupts :
  {
	__vector_table = .;
    . = ALIGN(4);
    KEEP(*(.vectortable)) /* Startup code */
    . = ALIGN(4);
  } > m_interrupts

  /* The program code and other data goes into RAM */
  .app_text :
  {
    *(.text)           /* .text sections (code) */
    _etext = .;        /* define a global symbols at end of code */
    . = ALIGN(0x8);
  } > m_text
  
  .lib_text : {
    KEEP (*(.init))
	*(.libinit)
  	*(.libtext)
    . = ALIGN(0x8);
} > m_lib_text

  /* Initialized data sections goes into RAM, load LMA copy after code */
  .app_data :
  {
    . = ALIGN(4);
    _sdata = .;        /* create a global symbol at data start */
    *(.data)           /* .data sections */

     /* This is used by the startup in order to initialize the .bss section */
    __START_BSS = .;
	PROVIDE ( __bss_start__ = __START_BSS );
    *(.bss)
    *(COMMON)
	. = ALIGN(4);
    __END_BSS = .;
	PROVIDE ( __bss_end__ = __END_BSS );
    . = ALIGN(0x8);
    
    *(.sdata)
	. = ALIGN(0x4);
    __sinit__ = .;
    . = ALIGN(0x4);
    
    *(.rodata)         /* .rodata sections (constants, strings, etc.) */
    *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
    . = ALIGN(4);
    _edata = .;        /* define a global symbol at data end */
  } > m_data

.lib_data : {
	*(.libinitdata)
	*(.libdata)
	    . = ALIGN(0x4);
	*(.ARM.extab)
		. = ALIGN(0x4);
} > m_lib_data

.stack_data : {
   	*(.stackdata)
	. = ALIGN(0x4);
} > m_stack

.heap_data : {
   	*(.heapdata)
	. = ALIGN(0x4);
 } > m_heap
 
  __S_romp = 0;
  .ARM.attributes 0 : { *(.ARM.attributes) }
}
