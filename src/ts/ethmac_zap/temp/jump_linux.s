.global jump_to_linux
.func   jump_to_linux

@ void jump_to_linux(void)
@
@ Follows ARM Linux boot protocol exactly:
@   r0 = 0
@   r1 = 0xFFFFFFFF (use DTB for machine detection)
@   r2 = DTB physical address
@   MMU off, caches off, IRQ/FIQ disabled, SVC mode
@
@ Reference: Documentation/arm/booting.rst

jump_to_linux:

    @ ---------------------------------------------------------------
    @ 1. Switch to SVC mode, disable IRQ and FIQ
    @ ---------------------------------------------------------------
    mov r4, #0xD3               @ SVC mode | IRQ disabled | FIQ disabled
    msr cpsr_c, r4

    @ ---------------------------------------------------------------
    @ 2. Flush D-cache before disabling it
    @    (drain write buffer so all stores reach DRAM)
    @ ---------------------------------------------------------------
    mov r4, #0
    mcr p15, 0, r4, c7, c10, 4  @ drain write buffer

    @ ---------------------------------------------------------------
    @ 3. Disable MMU, D-cache, I-cache
    @    c1,c0,0 = System Control Register
    @    bit 0 (M) = MMU
    @    bit 2 (C) = D-cache
    @    bit 12 (I) = I-cache
    @ ---------------------------------------------------------------
    mrc p15, 0, r4, c1, c0, 0
    bic r4, r4, #0x1000          @ clear I bit: I-cache off
    bic r4, r4, #0x0007          @ clear M,A,C bits: MMU off, D-cache off
    mcr p15, 0, r4, c1, c0, 0

    @ ---------------------------------------------------------------
    @ 4. Invalidate TLB, I-cache, D-cache after MMU/cache off
    @ ---------------------------------------------------------------
    mov r4, #0
    mcr p15, 0, r4, c8, c7, 0   @ invalidate unified TLB
    mcr p15, 0, r4, c7, c5, 0   @ invalidate I-cache
    mcr p15, 0, r4, c7, c6, 0   @ invalidate D-cache
    mcr p15, 0, r4, c7, c10, 4  @ drain write buffer again

    @ ---------------------------------------------------------------
    @ 5. Set up Linux ARM boot registers
    @    r0 = 0                (required)
    @    r1 = 0xFFFFFFFF      (machine type: use DTB)
    @    r2 = DTB address     (physical address of .dtb)
    @ ---------------------------------------------------------------
    mov r0, #0
    ldr r1, =0xFFFFFFFF
    ldr r2, =0x10400000         @ DTB at 0x10400000

    @ ---------------------------------------------------------------
    @ 6. Jump to zImage entry point
    @    zImage loads at 0x10800000, entry is at offset 0x20
    @    (8 NOPs then branch instruction EA000005)
    @ ---------------------------------------------------------------
    ldr pc, =0x10800020

.endfunc
