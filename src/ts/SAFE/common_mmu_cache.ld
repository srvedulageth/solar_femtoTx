ENTRY(_Reset)

MEMORY
{
  BRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
  . = 0x00000000;

  .text :
  {
    KEEP(obj/ts/ethmac_zap/uart_start.o(.text*))
    *(.text*)
    *(.rodata*)
  } > BRAM

  .data :
  {
    *(.data*)
  } > BRAM

  .bss :
  {
    *(.bss*)
    *(COMMON)
  } > BRAM

  . = ALIGN(4);
  __image_end = .;

  ASSERT(__image_end <= 0x0000C000, "ERROR: image overlaps L1 table")

  .l1_table 0x0000C000 (NOLOAD) :
  {
    __l1_table_base = .;
    . = . + 0x4000;
    __l1_table_end = .;
  } > BRAM

  ASSERT(__l1_table_end <= 0x00010000, "ERROR: L1 table exceeds BRAM")
}
