.set USER_STACK_POINTER,  0x00003DF0
.set IRQ_STACK_POINTER,   0x00003EF0
.set FIQ_STACK_POINTER,   0x00003FF0

.set VIC_BASE_ADDRESS,    0xFFFFFFA0
.set L1_TABLE_BASE,       0x00004000

/* Section descriptor bits
 *
 * Section entry format (ARMv4/v5 style):
 *   [31:20] section base address
 *   [19:12] misc
 *   [11:10] AP
 *   [8:5]   domain
 *   [3]     C
 *   [2]     B
 *   [1:0]   0b10 = section
 *
 * We use domain 0, AP=3 (full access)
 *
 * Cacheable/bufferable section:
 *   AP=3, domain=0, C=1, B=1, type=section
 *   -> 0x00000C0E
 *
 * Uncached/unbuffered section:
 *   AP=3, domain=0, C=0, B=0, type=section
 *   -> 0x00000C02
 */
.set DESC_SECTION_CACHEABLE, 0x00000C0E
.set DESC_SECTION_UNCACHED,  0x00000C02

.text
.global _Reset
.global mmu_setup
.global mmu_enable
_Reset:

_Reset   : b there
_Undef   : b _Undef
_Swi     : b _Swi
_Pabt    : b _Pabt
_Dabt    : b _Dabt
reserved : b reserved
irq      : b sc_call
fiq      : b sc_call

/*
 * This handler simply revectors IRQs to
 * a dedicated irq_handler function. This
 * is a common routine for IRQ and FIQ.
 */
sc_call:
sub r14, r14, #4
stmfd sp!, {r0-r12, r14}
bl irq_handler
ldmfd sp!, {r0-r12, pc}^

there:
/*
 * Switch to IRQ mode.
 * Set up stack pointer.
 */
mrs r2, cpsr
bic r2, r2, #31
orr r2, r2, #18
msr cpsr_c, r2
ldr sp, =IRQ_STACK_POINTER

/*
 * Switch to FIQ mode.
 * Setup up stack pointer.
 */
mrs r2, cpsr
bic r2, r2, #31
orr r2, r2, #17
msr cpsr_c, r2
ldr sp, =FIQ_STACK_POINTER

/*
 * Switch to user mode with interrupts enabled.
 * Set up stack pointer.
 */
mrs r1, cpsr
bic r1, r1, #31
orr r1, r1, #16
bic r1, r1, #0xC0
msr cpsr_c, r1

/*
 * Unmask all interrupts in the VIC.
 */
ldr r0, =VIC_BASE_ADDRESS // VIC base address.
add r0, r0, #4            // Move to INT_MASK
mov r1, #0                // Prepare mask value
str r1, [r0]              // Unmask all interrupt sources.
ldr r1, [r0]              // No change to R1 value.

/* Build MMU translation table
bl    mmu_setup */

/* Enable MMU + I-cache + D-cache
bl    mmu_enable */

/*
 * Then call the main function. The main function
 * will initiallize UART0 in TX and RX.
 */
ldr sp, =USER_STACK_POINTER
bl main
here: b here


/* ------------------------------------------------------------------ */
/* Build first-level translation table                                */
/* ------------------------------------------------------------------ */
mmu_setup:
    /* r0 = L1 table base */
    ldr   r0, =L1_TABLE_BASE

    /* Clear all 4096 entries */
    mov   r1, #0
    mov   r2, #4096
1:
    str   r1, [r0], #4
    subs  r2, r2, #1
    bne   1b

    /* Restore table base */
    ldr   r0, =L1_TABLE_BASE

    /* -------------------------------------------------------------- */
    /* Map 0x00000000 - 0x000FFFFF (boot BRAM / low memory)           */
    /* VA = PA, cacheable                                             */
    /* Section index = 0x000                                          */
    /* -------------------------------------------------------------- */
    ldr   r1, =0x00000000
    ldr   r2, =DESC_SECTION_CACHEABLE
    orr   r3, r1, r2
    str   r3, [r0, #(0x000 * 4)]

    /* -------------------------------------------------------------- */
    /* Map DDR 0x10000000 - 0x1FFFFFFF (256 MB)                       */
    /* cacheable                                                      */
    /* Section index starts at 0x100                                  */
    /* -------------------------------------------------------------- */
    ldr   r4, =0x10000000      /* physical section base */
    mov   r5, #0x100           /* virtual section index */
    mov   r6, #256             /* 256 x 1MB sections */
2:
    ldr   r2, =DESC_SECTION_CACHEABLE
    orr   r3, r4, r2
    str   r3, [r0, r5, lsl #2]
    add   r4, r4, #0x00100000
    add   r5, r5, #1
    subs  r6, r6, #1
    bne   2b

    /* -------------------------------------------------------------- */
    /* Map top MMIO section 0xFFF00000 - 0xFFFFFFFF as uncached       */
    /* Covers UART/TIMER/VIC/ETH regs at 0xFFFFFFxx                   */
    /* Section index = 0xFFF                                          */
    /* -------------------------------------------------------------- */
    ldr   r1, =0xFFF00000
    ldr   r2, =DESC_SECTION_UNCACHED
    orr   r3, r1, r2
    ldr   r4, =0xFFF
    str   r3, [r0, r4, lsl #2]

    mov   pc, lr


/* ------------------------------------------------------------------ */
/* Enable MMU + caches                                                */
/* ------------------------------------------------------------------ */
mmu_enable:
    /* TTBR = page table base */
    ldr   r0, =L1_TABLE_BASE
    mcr   p15, 0, r0, c2, c0, 0

    /* Domain access control = manager for all domains */
    mvn   r0, #0
    mcr   p15, 0, r0, c3, c0, 0

    /* Invalidate TLB */
    mov   r0, #0
    mcr   p15, 0, r0, c8, c7, 0

    /* Invalidate I-cache */
    mcr   p15, 0, r0, c7, c5, 0

    /* Invalidate D-cache */
    mcr   p15, 0, r0, c7, c6, 0

    /* Read system control register */
    mrc   p15, 0, r0, c1, c0, 0

    /* Enable:
     * bit 0  = MMU
     * bit 2  = D-cache
     * bit 12 = I-cache
     */
    orr   r0, r0, #0x0001
    orr   r0, r0, #0x0004
    orr   r0, r0, #0x1000

    /* Write system control register */
    mcr   p15, 0, r0, c1, c0, 0

    mov   pc, lr
