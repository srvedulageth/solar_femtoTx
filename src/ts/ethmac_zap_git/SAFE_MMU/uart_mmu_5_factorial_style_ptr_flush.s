.set USER_STACK_POINTER, 0x0000B7F0
.set IRQ_STACK_POINTER,  0x0000BBF0
.set FIQ_STACK_POINTER,  0x0000BFF0
.set UND_STACK_POINTER,  0x0000B3F0
.set VIC_BASE_ADDRESS,   0xFFFFFFA0
.extern __l1_table_base

.text
.global _Reset
_Reset:

/* Exception vector table: keep this exactly 8 words at 0x00..0x1c */
_Reset   : b there
_Undef   : b UNDEF
_Swi     : b SWI
_Pabt    : b PABT
_Dabt    : b DABT
reserved : b _Reset
irq      : b IRQ
fiq      : b FIQ

/* ------------------------------------------------------------------------- */
/* Minimal trap handlers                                                     */
/* ------------------------------------------------------------------------- */
UNDEF:
    stmfa sp!, {r0-r12, r14}
    ldmfa sp!, {r0-r12, pc}^

SWI:
    stmfd sp!, {r0-r12, r14}
    ldmfd sp!, {r0-r12, pc}^

PABT:
    b PABT

DABT:
    b DABT

/* ------------------------------------------------------------------------- */
/* IRQ handler: modelled after ZAP factorial.s                               */
/* Calls C irq_handler(), then returns with pc^ to restore CPSR from SPSR.    */
/* ------------------------------------------------------------------------- */
IRQ:
    sub r14, r14, #4
    stmfd sp!, {r0-r12, r14}

    bl irq_handler

    ldmfd sp!, {r0-r12, pc}^

/* ------------------------------------------------------------------------- */
/* FIQ handler: modelled after ZAP factorial.s                               */
/* In FIQ mode, r8-r14 are banked, so only save r0-r7 plus return lr.         */
/* If you do not use FIQ, this is still safe.                                 */
/* ------------------------------------------------------------------------- */
FIQ:
    sub r14, r14, #4
    stmfd sp!, {r0-r7, r14}

    bl irq_handler

    ldmfd sp!, {r0-r7, pc}^

/* ------------------------------------------------------------------------- */
/* Reset/startup                                                             */
/* ------------------------------------------------------------------------- */
there:
    /* Switch to IRQ mode and set IRQ stack */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #18
    msr cpsr_c, r2
    ldr sp, =IRQ_STACK_POINTER

    /* Switch to FIQ mode and set FIQ stack */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #17
    msr cpsr_c, r2
    ldr sp, =FIQ_STACK_POINTER

    /* Switch to UND mode and set UND stack */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #27
    msr cpsr_c, r2
    ldr sp, =UND_STACK_POINTER

    /* Return to user mode, interrupts enabled, matching factorial.s style */
    mrs r1, cpsr
    bic r1, r1, #31
    orr r1, r1, #16
    bic r1, r1, #0xC0
    msr cpsr_c, r1
    ldr sp, =USER_STACK_POINTER

    /* --------------------------------------------------------------------- */
    /* Enable cache first, exactly like ZAP factorial.s.                      */
    /* 4100 enables both caches in the original test.                         */
    /* --------------------------------------------------------------------- */
    //.set ENABLE_CACHE_CP_WORD, 4100
    //ldr r1, =ENABLE_CACHE_CP_WORD
    //mcr p15, 0, r1, c1, c1, 0

    /* Translation table base = 0x4000, same CP15 encoding as factorial.s */
    ldr r1, =__l1_table_base
    mcr p15, 0, r1, c2, c0, 1

    /* Domain access control = all 1s */
    mvn r1, #0
    mcr p15, 0, r1, c3, c0, 0

    /* --------------------------------------------------------------------- */
    /* Build only the descriptors this Ethernet bare-metal test needs.        */
    /* IMPORTANT: use pointer arithmetic from __l1_table_base.                */
    /* This avoids any scaled-index/addressing ambiguity and makes the        */
    /* write addresses explicit:                                              */
    /*   entry 0x000 -> __l1_table_base + 0x0000                              */
    /*   entry 0x100 -> __l1_table_base + 0x0400                              */
    /*   entry 0xFFF -> __l1_table_base + 0x3FFC                              */
    /* --------------------------------------------------------------------- */

    /* r5 = L1 table base from linker script, expected 0x0000C000 */
    ldr r5, =__l1_table_base

    /* Descriptor 0: VA 0x00000000 -> PA 0x00000000.                         */
    /* Keep low BRAM/code section cacheable to match the original ZAP test.   */
    mov r2, #14                 /* 0x0000000E cacheable section descriptor */
    str r2, [r5]

    /* Descriptor 0x100 address = base + 0x100*4 = base + 0x400.              */
    ldr r6, =0x400
    add r6, r5, r6

    /* First DDR MB: 0x10000000 - 0x100FFFFF.                                 */
    /* Use UNCACHED because EthMAC packet buffers begin in this section.       */
    ldr r2, =0x10000002
    str r2, [r6], #4            /* write entry 0x100, then advance to 0x101 */

    /* Descriptors 0x101..0x1FF: remaining DDR cacheable.                     */
    /* If this causes instability, change 0x1010000E to 0x10100002            */
    /* or comment this loop out and map only the first DDR MB for Ethernet.    */
    ldr r2, =0x1010000E
    mov r4, #255
DDR_CACHEABLE_LOOP:
    str r2, [r6], #4
    add r2, r2, #0x00100000
    subs r4, r4, #1
    bne DDR_CACHEABLE_LOOP

    /* Descriptor 4095: address = base + 4095*4 = base + 0x3FFC.              */
    /* VA 0xFFF00000 -> PA 0xFFF00000, uncached MMIO.                         */
    /* Covers UART, TIMER, VIC, EthMAC regs, and internal EthMAC BD RAM.       */
    ldr r6, =0x3FFC
    add r6, r5, r6
    ldr r2, =0xFFF00002
    str r2, [r6]

    /* --------------------------------------------------------------------- */
    /* Flush prefetch buffer before changing MMU/cache state.                 */
    /* If ZAP does not support this CP15 op, remove these c7,c5,4 lines only. */
    /* --------------------------------------------------------------------- */
    //mov r0, #0
    //mcr p15, 0, r0, c7, c5, 4

    /* ENABLE MMU + caches, exactly like ZAP factorial.s.                     */
    /* For MMU-only debug, change 4101 to 4001.                               */
    .set ENABLE_MMU_CP_WORD, 4101
    ldr r1, =ENABLE_MMU_CP_WORD
    mcr p15, 0, r1, c1, c1, 0

    /* Flush prefetch again after enabling MMU/cache.                         */
    //mov r0, #0
    //mcr p15, 0, r0, c7, c5, 4

    /* A few harmless NOPs give the pipeline time to settle in simulation. */
    mov r0, r0
    mov r0, r0
    mov r0, r0

    /* Unmask all interrupts in the VIC */
    ldr r0, =VIC_BASE_ADDRESS
    add r0, r0, #4
    mov r1, #0
    str r1, [r0]
    ldr r1, [r0]

    /* Call C main */
    bl main

here:
    b here
