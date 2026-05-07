.set USER_STACK_POINTER, 0x0000F7F0
.set IRQ_STACK_POINTER,  0x0000FBF0
.set FIQ_STACK_POINTER,  0x0000FFF0
.set VIC_BASE_ADDRESS,   0xFFFFFFA0
.set L1_TABLE_BASE,      0x00004000

/*
 * ZAP MMU bring-up notes:
 * - Build a FULL 4096-entry 1MB-section identity map BEFORE enabling MMU.
 * - Low processor RAM / vectors / stacks stay UNCACHED for stability.
 * - First DDR MB, 0x10000000-0x100FFFFF, stays UNCACHED for EthMAC packet buffers.
 * - Remaining DDR, 0x10100000-0x1FFFFFFF, is CACHEABLE.
 * - MMIO region, including EthMAC/VIC/UART/TIMER at 0xFFFFxxxx, is UNCACHED.
 *
 * Descriptor convention used by the ZAP test code:
 *   section uncached  = PA_BASE | 0x00000002
 *   section cacheable = PA_BASE | 0x0000000E
 */

.text
.global _Reset
_Reset:

_Reset   : b there
_Undef   : b _Undef
_Swi     : b _Swi
_Pabt    : b _Pabt
_Dabt    : b _Dabt
reserved : b reserved
irq      : b sc_call
fiq      : b fiq

/*
 * IRQ handler wrapper.
 * FIQ is intentionally not used for normal EthMAC/timer IRQs.
 */
sc_call:
    sub lr, lr, #4
    stmfd sp!, {r0-r12, lr}

    bl irq_handler

    ldmfd sp!, {r0-r12, lr}
    subs pc, lr, #0

there:
    /*
     * TTBR / translation table base = 16KB aligned.
     * This follows the ZAP test-case CP15 encoding.
     */
    ldr r1, =L1_TABLE_BASE
    mcr p15, 0, r1, c2, c0, 1

    /* Domain access control = all 1s */
    mvn r1, #0
    mcr p15, 0, r1, c3, c0, 0

    /*
     * Build FULL 4GB identity map as UNCACHED sections.
     * This replaces both the old clear_l1_loop and the partial map.
     * Every L1 entry gets a known-good section descriptor.
     */
    ldr r0, =L1_TABLE_BASE      /* r0 = L1 table base */
    mov r1, #0                  /* r1 = section index, 0..4095 */
    ldr r3, =4096               /* r3 = loop limit */

identity_map_loop:
    mov r2, r1, lsl #20         /* r2 = physical section base */
    orr r2, r2, #0x02           /* uncached section descriptor */
    str r2, [r0, r1, lsl #2]    /* table[index] = descriptor */
    add r1, r1, #1
    cmp r1, r3
    bne identity_map_loop

    /*
     * Keep first DDR MB uncached for EthMAC packet buffers:
     *   ETHMAC_BUF_RAM_BASE    = 0x10000000
     *   ETHMAC_RX_BUF_RAM_BASE = 0x10020000
     * The identity map already made this uncached, so no write needed.
     */

    /*
     * Map remaining DDR 0x10100000 - 0x1FFFFFFF as CACHEABLE.
     * If this causes any instability, comment this loop out and run all-DDR-uncached.
     */
    ldr r0, =L1_TABLE_BASE
    ldr r1, =0x1010000E         /* descriptor for 0x10100000 cacheable */
    ldr r2, =0x101              /* first cacheable DDR section index */
    mov r3, #255                /* 0x101..0x1FF inclusive */

ddr_cacheable_map_loop:
    str r1, [r0, r2, lsl #2]
    add r1, r1, #0x00100000
    add r2, r2, #1
    subs r3, r3, #1
    bne ddr_cacheable_map_loop

    /*
     * Force MMIO top section uncached.
     * Full identity map already did this, but this explicit write documents intent.
     */
    ldr r0, =L1_TABLE_BASE
    ldr r2, =16380              /* 4095 * 4 */
    add r0, r0, r2
    ldr r1, =0xFFF00002
    str r1, [r0]

    /* Invalidate TLB + I-cache + prefetch buffer before enable. */
    mov r0, #0
    mcr p15, 0, r0, c8, c7, 0   /* invalidate unified TLB */
    mcr p15, 0, r0, c7, c5, 0   /* invalidate I-cache */
    mcr p15, 0, r0, c7, c5, 4   /* flush prefetch buffer */

    /*
     * Enable MMU + caches using ZAP test-case control word.
     * You said 4101 enables both cache and MMU; 4001 enables MMU only.
     * For MMU-only debug, change 4101 to 4001 here.
     */
    ldr r1, =4101
    mcr p15, 0, r1, c1, c1, 0

    /* Flush prefetch again after enable. */
    mov r0, #0
    mcr p15, 0, r0, c7, c5, 4

    /*
     * Switch to IRQ mode and set stack pointer.
     */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #18
    msr cpsr_c, r2
    ldr sp, =IRQ_STACK_POINTER

    /*
     * Switch to FIQ mode and set stack pointer.
     */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #17
    msr cpsr_c, r2
    ldr sp, =FIQ_STACK_POINTER

    /*
     * Switch to user mode with interrupts enabled and set stack pointer.
     */
    mrs r1, cpsr
    bic r1, r1, #31
    orr r1, r1, #16
    bic r1, r1, #0xC0
    msr cpsr_c, r1

    /*
     * Unmask all interrupts in the VIC.
     */
    ldr r0, =VIC_BASE_ADDRESS
    add r0, r0, #4
    mov r1, #0
    str r1, [r0]
    ldr r1, [r0]

    /*
     * Then call main.
     */
    ldr sp, =USER_STACK_POINTER
    bl main

here:
    b here
