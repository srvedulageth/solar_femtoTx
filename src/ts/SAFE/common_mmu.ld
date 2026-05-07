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
    KEEP(*(.text._Reset))
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

  /* Reserve 16KB L1 page table at top of 64KB BRAM */
  . = 0x0000C000;
  __l1_table_base = .;

  .l1_table (NOLOAD) :
  {
    . = . + 0x4000;
  } > BRAM

  __l1_table_end = .;

  ASSERT(__image_end <= 0x0000C000, "ERROR: program overlaps L1 page table")
  ASSERT(__l1_table_end <= 0x00010000, "ERROR: L1 page table exceeds BRAM")
}
