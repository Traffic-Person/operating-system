OUTPUT_FORMAT("elf32-i386")
ENTRY(kmain)

SECTIONS
{
  . = 0x00100000 /*load at 1mb*/
  .text : { *(.text) }
  .rodata : { *(.rodata) }
  .data : { *(.data) }
  .bss : { *(.bss) }
}
